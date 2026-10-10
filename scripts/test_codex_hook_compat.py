import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys


spec = importlib.util.spec_from_file_location("compat", Path(__file__).with_name("codex-hook-compat.py"))
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)


class HookCompatibilityTest(unittest.TestCase):
    def test_repair_preserves_hooks_backup_and_trust_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hooks.json"
            valid = {"type": "command", "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/lifecycle/sessionStart.mjs"], "timeout": 10}
            existing = {"type": "command", "command": "bash working.sh"}
            unknown = {"type": "command", "command": "node", "args": ["$(untrusted)/script.mjs"]}
            original = json.dumps({"hooks": {"SessionStart": [{"hooks": [valid, existing, unknown]}]}}).encode()
            path.write_bytes(original)
            path.chmod(0o644)
            self.assertEqual(compat.repair(path), 1)
            hooks = json.loads(path.read_bytes())["hooks"]["SessionStart"][0]["hooks"]
            self.assertEqual(hooks[0], {"type": "command", "command": 'node "${CLAUDE_PLUGIN_ROOT}/scripts/lifecycle/sessionStart.mjs"', "timeout": 10})
            self.assertEqual(hooks[1:], [existing, unknown])
            self.assertEqual(path.with_name("hooks.json.codex-compat-backup").read_bytes(), original)
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
            repaired = path.read_bytes()
            self.assertEqual(compat.repair(path), 0)
            self.assertEqual(path.read_bytes(), repaired)
            self.assertFalse((path.parent / "config.toml").exists())

    def test_symlink_is_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "target.json"
            target.write_text('{}')
            path = Path(directory) / "hooks.json"
            path.symlink_to(target)
            self.assertEqual(compat.repair(path), 0)
            self.assertEqual(target.read_text(), '{}')

    def test_invalid_manifest_does_not_prevent_other_repairs_or_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "plugins/cache/claude-plugins-official/stripe"
            broken = root / "1/hooks/hooks.json"
            broken.parent.mkdir(parents=True)
            broken.write_text('{')
            good = root / "2/hooks/hooks.json"
            good.parent.mkdir(parents=True)
            good.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [
                {"type": "command", "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/lifecycle/postToolBatch.mjs"]},
                {"type": "command", "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/lifecycle/unknown.mjs"]},
            ]}]}}))
            result = subprocess.run([sys.executable, spec.origin, "--codex-home", directory], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn("skipped", result.stderr)
            self.assertEqual(broken.read_text(), '{')
            hooks = json.loads(good.read_text())["hooks"]["Stop"][0]["hooks"]
            self.assertNotIn("args", hooks[0])
            self.assertIn("args", hooks[1])


if __name__ == "__main__":
    unittest.main()
