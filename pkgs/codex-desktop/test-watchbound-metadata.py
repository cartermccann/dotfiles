"""Focused synthetic tests; no GUI, installed app, or user profile access."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "patch_watchbound", Path(__file__).with_name("patch-watchbound-metadata.py"))
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)


def encode(header, payload):
    data = json.dumps(header, separators=(",", ":")).encode()
    padded = (len(data) + 3) & ~3
    return (struct.pack("<IIII", 4, 8 + padded, 4 + padded, len(data))
            + data + b"\0" * (padded - len(data)) + payload)


def set_entry(header, name, entry):
    current = header
    parts = name.split("/")
    for component in parts[:-1]:
        current = current.setdefault("files", {}).setdefault(component, {})
    current.setdefault("files", {})[parts[-1]] = entry


class RepairTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="watchbound-metadata-test-")
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.archive = root / "app.asar"
        self.report = root / "mods.json"
        self.report.write_text(json.dumps({"composerDictation": {"gate": "4100906017"}}))
        self.native = Path(str(self.archive) + ".unpacked") / patcher.NATIVE
        self.native.parent.mkdir(parents=True)
        elf = bytearray(64)
        elf[:7] = b"\x7fELF\x02\x01\x01"
        struct.pack_into("<HH", elf, 16, 3, 62)
        self.native.write_bytes(elf + b"relocated-runtime-path" * 8)
        manifest = {
            "name": "@gadicc/watchbound-node-linux-x64-gnu", "version": "2.1.2",
            "main": "./watchbound.linux-x64-gnu.node",
            "watchbound": {
                "delivery": "target-native-package", "target": "linux-x64-gnu",
                "architecture": "x64", "libc": "glibc",
                "binary": "watchbound.linux-x64-gnu.node",
                "nativeSha256": patcher.ORIGINAL_SHA256,
            },
        }
        self.manifest = json.dumps(manifest, indent=2).encode()
        self.before = b"untouched leading asset"
        self.after = b"untouched trailing asset"
        self.payload = self.before + self.manifest + self.after
        self.header = {"files": {}}
        set_entry(self.header, "before.txt", {
            "offset": "0", "size": len(self.before), "integrity": patcher.integrity(self.before)})
        set_entry(self.header, patcher.MANIFEST, {
            "offset": str(len(self.before)), "size": len(self.manifest),
            "integrity": patcher.integrity(self.manifest)})
        set_entry(self.header, patcher.NATIVE, {
            "unpacked": True, "size": patcher.ORIGINAL_SIZE,
            "integrity": {"algorithm": "SHA256", "hash": patcher.ORIGINAL_SHA256,
                          "blockSize": patcher.BLOCK_SIZE,
                          "blocks": [patcher.ORIGINAL_SHA256]},
        })
        set_entry(self.header, "after.txt", {
            "offset": str(len(self.before) + len(self.manifest)), "size": len(self.after),
            "integrity": patcher.integrity(self.after)})
        self.save()

    def save(self):
        self.archive.write_bytes(encode(self.header, self.payload))

    def repair(self):
        with contextlib.redirect_stdout(io.StringIO()):
            patcher.patch(self.archive, self.report)

    def assert_rejected_unchanged(self):
        original, report, native = (self.archive.read_bytes(), self.report.read_bytes(),
                                    self.native.read_bytes())
        with self.assertRaises((ValueError, FileNotFoundError)):
            self.repair()
        self.assertEqual(original, self.archive.read_bytes())
        self.assertEqual(report, self.report.read_bytes())
        self.assertEqual(native, self.native.read_bytes())

    def test_exact_metadata_repair_preserves_other_payloads_and_report(self):
        native = self.native.read_bytes()
        original_entries = copy.deepcopy(dict(patcher.entries(self.header)))
        self.repair()
        raw = self.archive.read_bytes()
        header, start = patcher.read_archive(raw)
        files = dict(patcher.entries(header))
        self.assertEqual(files[patcher.NATIVE]["size"], len(native))
        self.assertEqual(files[patcher.NATIVE]["integrity"], patcher.integrity(native))
        self.assertEqual(files[patcher.MANIFEST]["offset"], original_entries[patcher.MANIFEST]["offset"])
        self.assertEqual(files[patcher.MANIFEST]["size"], len(self.manifest))
        changed = raw[start + len(self.before):start + len(self.before) + len(self.manifest)]
        self.assertEqual(json.loads(changed)["watchbound"]["nativeSha256"],
                         patcher.integrity(native)["hash"])
        self.assertEqual(files[patcher.MANIFEST]["integrity"], patcher.integrity(changed))
        self.assertEqual(changed.replace(patcher.integrity(native)["hash"].encode(),
                                         patcher.ORIGINAL_SHA256.encode()), self.manifest)
        self.assertEqual(raw[start:start + len(self.before)], self.before)
        self.assertEqual(raw[-len(self.after):], self.after)
        for key in ("before.txt", "after.txt"):
            self.assertEqual(files[key], original_entries[key])
        self.assertEqual(self.native.read_bytes(), native)
        report = json.loads(self.report.read_bytes())
        self.assertEqual(report["composerDictation"], {"gate": "4100906017"})
        self.assertFalse(report[patcher.REPORT_KEY]["nativePayloadChanged"])
        self.assert_rejected_unchanged()  # Already applied must fail closed.

    def test_reject_original_metadata_drift(self):
        dict(patcher.entries(self.header))[patcher.NATIVE]["size"] += 1
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_manifest_integrity_drift(self):
        self.payload = self.payload.replace(b'"2.1.2"', b'"9.9.9"')
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_new_version_even_with_valid_integrity(self):
        self.payload = self.payload.replace(b'"2.1.2"', b'"2.1.3"')
        changed = self.manifest.replace(b'"2.1.2"', b'"2.1.3"')
        dict(patcher.entries(self.header))[patcher.MANIFEST]["integrity"] = patcher.integrity(changed)
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_multiple_native_targets(self):
        set_entry(self.header, "node_modules/@gadicc/watchbound-node-other/other.node", {})
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_native_not_unpacked(self):
        dict(patcher.entries(self.header))[patcher.NATIVE]["unpacked"] = False
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_invalid_elf(self):
        self.native.write_bytes(b"not an ELF")
        self.assert_rejected_unchanged()

    def test_reject_oversized_native(self):
        with self.native.open("r+b") as binary:
            binary.truncate(patcher.MAX_NATIVE_SIZE + 1)
        self.assert_rejected_unchanged()

    def test_reject_overlapping_packed_asset(self):
        dict(patcher.entries(self.header))["before.txt"]["size"] += 1
        self.save()
        self.assert_rejected_unchanged()

    def test_reject_native_symlink(self):
        real = self.native.with_suffix(".real")
        self.native.rename(real)
        self.native.symlink_to(real.name)
        self.assert_rejected_unchanged()

    def test_reject_duplicate_json_keys(self):
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            patcher.decode('{"nativeSha256": "a", "nativeSha256": "b"}')

    def test_reject_truncated_archive(self):
        self.archive.write_bytes(b"truncated")
        self.assert_rejected_unchanged()

    def test_reject_conflicting_report(self):
        self.report.write_text(json.dumps({patcher.REPORT_KEY: {}}))
        self.assert_rejected_unchanged()


if __name__ == "__main__":
    unittest.main()
