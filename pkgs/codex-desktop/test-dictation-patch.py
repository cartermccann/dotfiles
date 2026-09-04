import contextlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("patcher", Path(__file__).with_name("patch-composer-dictation.py"))
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)

SOURCE = (
    b'()=>{if(!navigator?.mediaDevices?.getUserMedia||typeof MediaRecorder>`u`)'
    b'return{isCapable:!1};let t=e(KE,`4100906017`),n=e(GE,`4100906017`),'
    b'{authLoading:r,authMethod:i}=e(Nk),a=r||t;'
    b'return{isLoading:a,isError:!1,isCapable:!a&&n&&i===`chatgpt`}}'
)


def archive_bytes(source):
    entry = {"offset": "0", "size": len(source), "integrity": patcher.integrity(source, 64)}
    tree = {"files": {"webview": {"files": {"assets": {"files": {"app.js": entry}}}},
                      "unchanged.txt": {"offset": str(len(source)), "size": 9},
                      "native.node": {"unpacked": True, "size": 123}}}
    header = json.dumps(tree).encode()
    padding = (-len(header)) % 4
    return struct.pack("<IIII", 4, 8 + len(header) + padding, 4 + len(header) + padding, len(header)) + header + b"\0" * padding + source + b"unchanged"


class DictationPatchTests(unittest.TestCase):
    def run_patch(self, data):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        archive = Path(directory.name) / "app.asar"
        report = Path(directory.name) / "report.json"
        archive.write_bytes(data)
        with contextlib.redirect_stdout(io.StringIO()):
            patcher.patch(archive, report)
        return archive, report

    def test_preserves_auth_and_unrelated_payload(self):
        archive, report = self.run_patch(archive_bytes(SOURCE))
        raw = archive.read_bytes()
        _, header_size, _, json_size = struct.unpack("<IIII", raw[:16])
        header = json.loads(raw[16:16 + json_size])
        entry = header["files"]["webview"]["files"]["assets"]["files"]["app.js"]
        payload = raw[8 + header_size:]
        changed = payload[:entry["size"]]
        self.assertEqual(len(changed), len(SOURCE))
        self.assertIn(b"isCapable:!a&&n&&i===`chatgpt`", changed)
        self.assertIn(b"navigator?.mediaDevices?.getUserMedia", changed)
        self.assertIn(b"n=!0/*cjmDictation*/", changed)
        self.assertEqual(payload[entry["size"]:], b"unchanged")
        self.assertEqual(header["files"]["native.node"], {"unpacked": True, "size": 123})
        self.assertEqual(entry["integrity"], patcher.integrity(changed, 64))
        self.assertEqual(json.loads(report.read_text())["composerDictation"]["authenticationRequired"], "chatgpt")

    def test_rejects_missing_or_duplicate_contract(self):
        for source in (SOURCE.replace(b"4100906017", b"9999999999"), SOURCE + SOURCE):
            with self.subTest(source_size=len(source)), self.assertRaises(ValueError):
                self.run_patch(archive_bytes(source))

    def test_rejects_corrupt_original(self):
        data = archive_bytes(SOURCE)
        with self.assertRaisesRegex(ValueError, "integrity mismatch"):
            self.run_patch(data.replace(b"authMethod:i", b"authMethod:j"))

    def test_rejects_reapplication(self):
        archive, report = self.run_patch(archive_bytes(SOURCE))
        before = archive.read_bytes()
        with self.assertRaisesRegex(ValueError, "already present"):
            patcher.patch(archive, report)
        self.assertEqual(before, archive.read_bytes())


if __name__ == "__main__":
    unittest.main()
