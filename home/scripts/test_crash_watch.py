#!/usr/bin/env python3
"""Unit tests for crash-watch compose + fallback (no TypeSafe, no journal)."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("crash_watch", ROOT / "crash-watch.py")
assert spec and spec.loader
cw = importlib.util.module_from_spec(spec)
sys.modules["crash_watch"] = cw
spec.loader.exec_module(cw)


def judgment(**kwargs) -> cw.Judgment:
    base = dict(
        should_see=0.9,
        do_not_interrupt=0.1,
        action="banner",
        action_confidence=0.85,
        warrant=1.8,
        should_mute=0.1,
        mute_justified=0.2,
        source="test",
    )
    base.update(kwargs)
    return cw.Judgment(**base)


class NameTests(unittest.TestCase):
    def test_prefers_exe_basename(self):
        self.assertEqual(cw.program_name("hyprland", "/usr/bin/Hyprland"), "Hyprland")

    def test_rejects_dot_and_empty(self):
        self.assertEqual(cw.program_name("-", ""), "unknown")
        self.assertEqual(cw.program_name("..", "/"), "unknown")

    def test_strips_slash_from_comm(self):
        self.assertEqual(cw.program_name("foo/bar", "-"), "bar")


class FilterTests(unittest.TestCase):
    def test_oom_sigkill(self):
        self.assertTrue(cw.signal_is_oom("SIGKILL"))
        self.assertTrue(cw.signal_is_oom("9"))
        self.assertFalse(cw.signal_is_oom("SIGSEGV"))

    def test_interpreters(self):
        for name in ("python3", "python3.13", "node", "bash"):
            self.assertTrue(cw.is_interpreter(name), name)
        self.assertFalse(cw.is_interpreter("zen"))

    def test_self_and_crashpad(self):
        self.assertTrue(cw.is_ignored("crash-watch"))
        self.assertTrue(cw.is_ignored("chrome_crashpad_handler"))
        self.assertFalse(cw.is_ignored("zen"))

    def test_code_drop_other_uid(self):
        crash = {"uid": 0, "signal": "SIGSEGV", "name": "zen"}
        self.assertEqual(cw.should_code_drop(crash, uid=1000), "uid")


class ComposeTests(unittest.TestCase):
    def test_unknown_or_low_confidence_queues(self):
        d = cw.compose({"name": "zen"}, judgment(action="unknown"), False)
        self.assertEqual(d.action, "silent-queue")
        d = cw.compose(
            {"name": "zen"},
            judgment(action="banner", action_confidence=0.2),
            False,
        )
        self.assertEqual(d.action, "silent-queue")

    def test_interrupt_cannot_banner(self):
        d = cw.compose(
            {"name": "zen"},
            judgment(do_not_interrupt=0.9, action="banner", warrant=1.8),
            False,
        )
        self.assertEqual(d.action, "silent-queue")
        self.assertFalse(d.sticky)
        self.assertFalse(d.punch_through_dnd)

    def test_sticky_needs_high_score_and_low_interrupt(self):
        d = cw.compose({"name": "zen"}, judgment(warrant=1.8, do_not_interrupt=0.1), False)
        self.assertEqual(d.action, "banner")
        self.assertTrue(d.sticky)
        d = cw.compose({"name": "zen"}, judgment(warrant=0.4, do_not_interrupt=0.1), False)
        self.assertEqual(d.action, "banner")
        self.assertFalse(d.sticky)

    def test_existing_mute_drops_until_lifted(self):
        d = cw.compose(
            {"name": "zen", "existing_mute": True},
            judgment(mute_justified=0.9),
            False,
        )
        self.assertEqual(d.action, "drop")
        self.assertFalse(d.lift_mute)
        d = cw.compose(
            {"name": "zen", "existing_mute": True},
            judgment(mute_justified=0.1, action="banner", action_confidence=0.9),
            False,
        )
        self.assertTrue(d.lift_mute)
        self.assertEqual(d.action, "banner")

    def test_lift_does_not_rewrite_mute(self):
        d = cw.compose(
            {"name": "zen", "existing_mute": True},
            judgment(mute_justified=0.1, should_mute=0.95, action="banner", action_confidence=0.9),
            False,
        )
        self.assertTrue(d.lift_mute)
        self.assertFalse(d.write_mute)

    def test_never_mute_interpreter(self):
        d = cw.compose({"name": "python3"}, judgment(should_mute=0.95), True)
        self.assertFalse(d.write_mute)

    def test_should_see_low_drops(self):
        d = cw.compose({"name": "helper"}, judgment(should_see=0.1), False)
        self.assertEqual(d.action, "drop")


class FallbackTests(unittest.TestCase):
    quiet = {
        "dnd": False,
        "fullscreen": False,
        "granola_mt_linked": False,
        "focused_class": "ghostty",
        "focused_title": "nvim",
    }
    meet = {
        "dnd": False,
        "fullscreen": False,
        "granola_mt_linked": True,
        "focused_class": "zen",
        "focused_title": "Meet - standup",
    }

    def test_quiet_native_crash_banners_sticky(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(crash, self.quiet, {"recent_same_name_count": 1}, {"exists": False})
        d = cw.compose({**crash, "existing_mute": False}, j, False)
        self.assertEqual(d.action, "banner")
        self.assertTrue(d.sticky)
        self.assertEqual(j.source, "fallback")

    def test_meeting_queues(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(crash, self.meet, {"recent_same_name_count": 1}, {"exists": False})
        d = cw.compose({**crash, "existing_mute": False}, j, False)
        self.assertEqual(d.action, "silent-queue")
        self.assertGreaterEqual(j.do_not_interrupt, 0.5)

    def test_true_fullscreen_queues_maximize_does_not(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        fs = {**self.quiet, "fullscreen": True}
        j = cw.fallback_judge(crash, fs, {"recent_same_name_count": 1}, {"exists": False})
        d = cw.compose({**crash, "existing_mute": False}, j, False)
        self.assertEqual(d.action, "silent-queue")
        # Super+F maximize is fullscreen=1 → collect_session stores False.
        j2 = cw.fallback_judge(crash, self.quiet, {"recent_same_name_count": 1}, {"exists": False})
        d2 = cw.compose({**crash, "existing_mute": False}, j2, False)
        self.assertEqual(d2.action, "banner")

    def test_repeat_mutes_native_not_python(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(
            crash, self.quiet, {"recent_same_name_count": 3}, {"exists": False}
        )
        d = cw.compose(crash, j, False)
        self.assertTrue(d.write_mute)
        py = {"name": "python3", "exe": "/bin/python3", "signal": "SIGSEGV"}
        j2 = cw.fallback_judge(
            py, self.quiet, {"recent_same_name_count": 5}, {"exists": False}
        )
        d2 = cw.compose(py, j2, True)
        self.assertFalse(d2.write_mute)

    def test_new_signal_lifts_mute(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGABRT"}
        mute = {"exists": True, "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(crash, self.quiet, {"recent_same_name_count": 1}, mute)
        d = cw.compose({**crash, "existing_mute": True}, j, False)
        self.assertTrue(d.lift_mute)
        self.assertNotEqual(d.action, "drop")


class DecideCliTests(unittest.TestCase):
    def test_decide_fallback_json(self):
        payload = {
            "crash": {
                "comm": "zen",
                "exe": "/bin/zen",
                "signal": "SIGSEGV",
                "name": "zen",
            },
            "session": FallbackTests.quiet,
            "history": {"recent_same_name_count": 1},
            "mute": {"exists": False},
        }
        proc = subprocess.run(
            [sys.executable, str(ROOT / "crash-watch.py"), "decide", "--fallback"],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        out = json.loads(proc.stdout)
        self.assertEqual(out["action"], "banner")
        self.assertTrue(out["sticky"])
        self.assertEqual(out["source"], "fallback")


def _pw_node(nid: int, name: str, media_class: str = "Audio/Sink") -> dict:
    return {
        "id": nid,
        "type": "PipeWire:Interface:Node",
        "info": {"props": {"node.name": name, "media.class": media_class}},
    }


def _pw_link(lid: int, out_n: int, in_n: int, *, canonical: bool = True, props: bool = False) -> dict:
    info: dict = {"props": {}}
    if canonical:
        info["output-node-id"] = out_n
        info["input-node-id"] = in_n
    if props:
        info["props"] = {"link.output.node": out_n, "link.input.node": in_n}
    return {"id": lid, "type": "PipeWire:Interface:Link", "info": info}


def granola_fixture(*, app_linked: bool, canonical: bool = True, props: bool = False) -> list:
    """Idle loopback always links granola_mt -> granola_mt.output."""
    nodes = [
        _pw_node(54, "granola_mt", "Audio/Sink"),
        _pw_node(55, "granola_mt.output", "Stream/Output/Audio"),
        _pw_node(56, "granola_mt.monitor", "Audio/Source"),
        _pw_node(90, "zen", "Stream/Output/Audio"),
    ]
    links = [_pw_link(200, 54, 55, canonical=canonical, props=props)]
    if app_linked:
        links.append(_pw_link(201, 90, 54, canonical=canonical, props=props))
    return nodes + links


class GranolaMtTests(unittest.TestCase):
    def test_idle_loopback_is_not_a_meeting(self):
        dump = granola_fixture(app_linked=False)
        self.assertFalse(cw.granola_mt_linked(dump))

    def test_app_stream_on_sink_is_a_meeting(self):
        dump = granola_fixture(app_linked=True)
        self.assertTrue(cw.granola_mt_linked(dump))

    def test_canonical_ids_not_props(self):
        dump = granola_fixture(app_linked=True, canonical=True, props=False)
        self.assertTrue(cw.granola_mt_linked(dump))
        idle = granola_fixture(app_linked=False, canonical=True, props=False)
        self.assertFalse(cw.granola_mt_linked(idle))

    def test_monitor_and_output_alone_do_not_count(self):
        dump = [
            _pw_node(54, "granola_mt"),
            _pw_node(56, "granola_mt.monitor"),
            _pw_link(202, 54, 56, canonical=True, props=False),
        ]
        self.assertFalse(cw.granola_mt_linked(dump))


class HyprFullscreenTests(unittest.TestCase):
    def test_maximize_is_not_interrupt(self):
        self.assertFalse(cw.hypr_true_fullscreen({"fullscreen": 1, "fullscreenClient": 1}))
        self.assertFalse(cw.hypr_true_fullscreen({"fullscreen": True}))
        self.assertFalse(cw.hypr_true_fullscreen({"fullscreen": 0}))

    def test_true_fullscreen_is_interrupt(self):
        self.assertTrue(cw.hypr_true_fullscreen({"fullscreen": 2, "fullscreenClient": 2}))
        self.assertTrue(cw.hypr_true_fullscreen({"fullscreen": 0, "fullscreenClient": 2}))


class DndSendPathTests(unittest.TestCase):
    dnd_only = {
        "dnd": True,
        "fullscreen": False,
        "granola_mt_linked": False,
        "focused_class": "ghostty",
        "focused_title": "nvim",
    }

    def test_dnd_alone_banners_and_punches(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(
            crash, self.dnd_only, {"recent_same_name_count": 1}, {"exists": False}
        )
        d = cw.compose({**crash, "existing_mute": False}, j, False)
        self.assertEqual(d.action, "banner")
        self.assertTrue(d.sticky)
        self.assertTrue(d.punch_through_dnd)
        self.assertLess(j.do_not_interrupt, 0.5)

    def test_meeting_still_cannot_banner(self):
        crash = {"name": "zen", "exe": "/bin/zen", "signal": "SIGSEGV"}
        j = cw.fallback_judge(
            crash, FallbackTests.meet, {"recent_same_name_count": 1}, {"exists": False}
        )
        d = cw.compose({**crash, "existing_mute": False}, j, False)
        self.assertEqual(d.action, "silent-queue")
        self.assertFalse(d.punch_through_dnd)


class AnnounceTests(unittest.TestCase):
    def test_silent_queue_does_not_notify(self):
        decision = cw.Decision(
            action="silent-queue",
            sticky=False,
            punch_through_dnd=False,
            write_mute=False,
            lift_mute=False,
            reason="judged",
            source="fallback",
        )
        with tempfile.TemporaryDirectory() as tmp:
            old = os.environ.get("XDG_STATE_HOME")
            os.environ["XDG_STATE_HOME"] = tmp
            try:
                with patch.object(cw, "notify") as notify, patch.object(
                    cw, "wait_for_notifications", return_value=True
                ):
                    ok = cw.announce(
                        {"name": "zen", "signal": "SIGSEGV", "exe": "/bin/zen"},
                        decision,
                    )
            finally:
                if old is None:
                    os.environ.pop("XDG_STATE_HOME", None)
                else:
                    os.environ["XDG_STATE_HOME"] = old
            self.assertTrue(ok)
            notify.assert_not_called()
            queue = Path(tmp) / "crash-watch" / "queue.jsonl"
            self.assertTrue(queue.is_file())
            line = json.loads(queue.read_text(encoding="utf-8").splitlines()[0])
            self.assertEqual(line["action"], "silent-queue")


if __name__ == "__main__":
    unittest.main()
