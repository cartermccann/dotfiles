import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("resize", Path(__file__).with_name("codex-voice-resize.py"))
resize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resize)


class ResizeTests(unittest.TestCase):
    def setUp(self):
        self.client = dict(address="0x123", pid=100, stableId="abc", **{
            "class": "codex-desktop", "initialClass": "codex-desktop",
            "title": "ChatGPT", "initialTitle": "ChatGPT", "floating": True,
            "mapped": True, "hidden": False, "xwayland": False, "fullscreen": 0,
            "monitor": 1, "at": [296, -1329], "size": [772, 3809]})
        self.monitor = dict(id=1, x=0, y=0, width=1920, height=1080,
                            scale=1.0, transform=3, reserved=[60, 10, 10, 10])

    def test_refuse_main_and_wrong_identity(self):
        for key, value in (("floating", False), ("xwayland", True), ("class", "other"),
                           ("title", "Other"), ("mapped", False), ("hidden", True)):
            with self.subTest(key=key), self.assertRaises(resize.Refusal):
                resize.select([{**self.client, key: value}], "0x123")

    def test_absent_and_ambiguous(self):
        for clients in ([], [self.client, self.client]):
            with self.assertRaises(resize.Refusal):
                resize.select(clients, "0x123")

    def test_portrait_workarea(self):
        self.assertEqual(resize.workarea(self.monitor), [60, 10, 1010, 1900])
        self.assertEqual(resize.plan(self.client, [self.monitor]),
                         {"at": [586, 34], "size": [460, 680]})

    def test_scaled_negative_monitor_and_clamp(self):
        m = {**self.monitor, "x": -640, "width": 1280, "height": 1000,
             "transform": 0, "scale": 2}
        target = resize.plan(self.client, [m])
        self.assertEqual(target, {"at": [-494, 34], "size": [460, 432]})

    def test_normal_window_and_tiny_monitor_refused(self):
        with self.assertRaises(resize.Refusal):
            resize.plan({**self.client, "size": [772, 900]}, [self.monitor])
        with self.assertRaises(resize.Refusal):
            resize.plan(self.client, [{**self.monitor, "width": 200, "height": 200}])

    def test_no_shell_and_injection_refused(self):
        target = {"at": [-20, 34], "size": [460, 680]}
        cmd = resize.lua_command(self.client, target)
        self.assertEqual(cmd[:2], ["hyprctl", "eval"])
        self.assertIn("relative=false, window=w", cmd[2])
        self.assertIn("w.stable_id==2748", cmd[2])
        for bad in ('0x123"; os.execute("false")', "$(false)", "ChatGPT"):
            with self.assertRaises(resize.Refusal):
                resize.lua_command({**self.client, "address": bad}, target)

    def test_rollback_rejects_reused_window_or_session(self):
        original = dict(version=1, session="test-session", identity=resize.identity(self.client),
                        original=resize.geometry(self.client))
        for field in ("pid", "stableId", "session"):
            data = json.loads(json.dumps(original))
            if field == "session":
                data[field] = "old-session"
            else:
                data["identity"][field] = "changed"
            with tempfile.NamedTemporaryFile(mode="w") as f:
                json.dump(data, f)
                f.flush()
                with patch.dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE="test-session"), \
                     patch.object(resize, "query", return_value=[self.client]), \
                     patch.object(resize.subprocess, "run") as run, \
                     self.assertRaises(resize.Refusal):
                    resize.main(["--address", "0x123", "--restore", f.name, "--apply"])
                run.assert_not_called()

    def test_snapshot_is_private_and_preserves_geometry(self):
        name = resize.snapshot({"original": resize.geometry(self.client)})
        try:
            self.assertEqual(os.stat(name).st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(Path(name).read_text())["original"]["size"], [772, 3809])
        finally:
            os.unlink(name)


if __name__ == "__main__":
    unittest.main()
