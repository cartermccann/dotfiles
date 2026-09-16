#!/usr/bin/env python3
"""Unit tests for crash-watch compose + fallback (no TypeSafe, no journal)."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
