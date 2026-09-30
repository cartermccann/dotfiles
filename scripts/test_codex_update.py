"""Exercise updater failure boundaries without downloads, builds, or live writes."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("updater", Path(__file__).with_name("codex-update.py"))
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.current = {
            "version": "0.155.1",
            "bundles": {system: {"target": target, "hash": "sha256-old"}
                        for system, target in updater.TARGETS.items()},
        }
        self.release = {
            "tag_name": "rust-v0.159.2", "draft": False, "prerelease": False,
            "assets": [{
                "name": f"codex-package-{target}.tar.zst",
                "digest": "sha256:" + "ab" * 32,
                "browser_download_url": f"https://github.com/openai/codex/releases/download/rust-v0.159.2/codex-package-{target}.tar.zst",
            } for target in updater.TARGETS.values()],
        }

    def test_check_does_not_download_or_mutate_sources(self):
        before = json.dumps(self.current)
        with patch.object(updater, "run") as run:
            result = updater.release_sources(self.current, self.release)
        run.assert_not_called()
        self.assertEqual(json.dumps(self.current), before)
        self.assertEqual(result["version"], "0.159.2")

    def test_download_hash_mismatch_aborts(self):
        with patch.object(updater, "run", return_value='{"hash":"sha256-wrong"}'):
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                updater.release_sources(self.current, self.release, download=True)

    def test_rejects_missing_duplicate_or_redirected_assets(self):
        for mutation in ("missing", "duplicate", "redirected", "no_digest"):
            release = json.loads(json.dumps(self.release))
            if mutation == "missing":
                release["assets"].pop()
            elif mutation == "duplicate":
                release["assets"].append(release["assets"][0])
            elif mutation == "redirected":
                release["assets"][0]["browser_download_url"] = "https://example.com/asset"
            else:
                release["assets"][0]["digest"] = None
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                updater.release_sources(self.current, release)

    def test_rejects_prerelease_and_downgrade(self):
        self.release["prerelease"] = True
        with self.assertRaises(ValueError):
            updater.release_sources(self.current, self.release)
        self.release["prerelease"] = False
        self.current["version"] = "0.200.0"
        with self.assertRaisesRegex(ValueError, "downgrade"):
            updater.release_sources(self.current, self.release)

    def test_lock_update_preserves_other_input_dependencies(self):
        before = {"root": "root", "nodes": {
            "root": {"inputs": {"codex-desktop-linux": "desktop", "other": "other"}},
            "desktop": {"locked": {"rev": "old"}},
            "other": {"inputs": {"dep": "dep"}},
            "dep": {"locked": {"rev": "old"}},
        }}
        after = json.loads(json.dumps(before))
        after["nodes"]["desktop"]["locked"]["rev"] = "new"
        updater.check_lock_scope(before, after)
        after["nodes"]["dep"]["locked"]["rev"] = "new"
        with self.assertRaisesRegex(ValueError, "unrelated input"):
            updater.check_lock_scope(before, after)

    def test_lock_follows_cannot_hide_unrelated_dependency_changes(self):
        before = {"root": "root", "nodes": {
            "root": {"inputs": {"codex-desktop-linux": "desktop", "other": "other"}},
            "desktop": {"inputs": {"nixpkgs": "dep"}},
            "other": {"inputs": {"nixpkgs": ["codex-desktop-linux", "nixpkgs"]}},
            "dep": {"locked": {"rev": "old"}},
        }}
        after = json.loads(json.dumps(before))
        after["nodes"]["dep"]["locked"]["rev"] = "new"
        with self.assertRaisesRegex(ValueError, "unrelated input"):
            updater.check_lock_scope(before, after)

    def transaction(self, validate):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / "pins").write_bytes(b"original local edits")
            (repo / "unrelated").write_bytes(b"keep")
            with patch.object(updater, "validate", side_effect=lambda root: validate(root)):
                with self.assertRaises((ValueError, subprocess.CalledProcessError, KeyboardInterrupt)):
                    updater.apply_and_build(repo, {"pins": b"original local edits"}, {"pins": b"candidate"})
            self.assertEqual((repo / "unrelated").read_bytes(), b"keep")
            return (repo / "pins").read_bytes()

    def test_failed_build_restores_preexisting_local_edits(self):
        def fail(repo):
            raise subprocess.CalledProcessError(1, "nh")
        self.assertEqual(self.transaction(fail), b"original local edits")

    def test_interrupted_build_restores_pins(self):
        def interrupt(repo):
            raise KeyboardInterrupt()
        self.assertEqual(self.transaction(interrupt), b"original local edits")

    def test_failed_build_preserves_concurrent_edit(self):
        def fail(repo):
            (repo / "pins").write_bytes(b"concurrent edit")
            raise subprocess.CalledProcessError(1, "nh")
        self.assertEqual(self.transaction(fail), b"concurrent edit")

    def test_successful_build_with_concurrent_edit_is_rejected(self):
        def changed(repo):
            (repo / "pins").write_bytes(b"concurrent edit")
        self.assertEqual(self.transaction(changed), b"concurrent edit")

    def test_changed_pin_before_apply_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / "pins").write_bytes(b"concurrent edit")
            with patch.object(updater, "validate") as validate:
                with self.assertRaisesRegex(ValueError, "during preparation"):
                    updater.apply_and_build(repo, {"pins": b"original"}, {"pins": b"candidate"})
            validate.assert_not_called()
            self.assertEqual((repo / "pins").read_bytes(), b"concurrent edit")

    def test_failed_atomic_replace_leaves_original_intact(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pins"
            path.write_bytes(b"original")
            with patch.object(updater.os, "replace", side_effect=OSError("disk error")):
                with self.assertRaises(OSError):
                    updater.atomic_write(path, b"candidate", b"original")
            self.assertEqual(path.read_bytes(), b"original")
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_concurrent_edit_between_candidate_writes_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            originals = {"first": b"original", "second": b"original"}
            candidates = {"first": b"candidate", "second": b"candidate"}
            for name, data in originals.items():
                (repo / name).write_bytes(data)
            atomic_write = updater.atomic_write

            def edit_after_first(path, data, expected):
                atomic_write(path, data, expected)
                if path.name == "first" and data == b"candidate":
                    (repo / "second").write_bytes(b"concurrent edit")

            with patch.object(updater, "atomic_write", side_effect=edit_after_first):
                with patch.object(updater, "validate") as validate:
                    with self.assertRaisesRegex(ValueError, "concurrent edit"):
                        updater.apply_and_build(repo, originals, candidates)
            validate.assert_not_called()
            self.assertEqual((repo / "first").read_bytes(), b"original")
            self.assertEqual((repo / "second").read_bytes(), b"concurrent edit")


if __name__ == "__main__":
    unittest.main()
