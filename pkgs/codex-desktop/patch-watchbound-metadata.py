"""Refresh Watchbound metadata after the Nix ELF relocation, without repacking.

The pinned Watchbound 2.1.2 x64 GNU artifact is unpacked. patchelf changes its
bytes after upstream packs the ASAR, leaving both Electron's stat metadata and
Watchbound's expected digest stale. Only that entry and its packed manifest may
change here; the native binary and all other packed bytes stay untouched.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import sys
import tempfile

PACKAGE = "node_modules/@gadicc/watchbound-node-linux-x64-gnu/"
MANIFEST = PACKAGE + "package.json"
NATIVE = PACKAGE + "watchbound.linux-x64-gnu.node"
ORIGINAL_SHA256 = "efe87e80a481d47dbe07d791f88e2f5b2116d96a5ef498376c57e64ba7461336"
ORIGINAL_SIZE = 1857568
BLOCK_SIZE = 4194304
MAX_NATIVE_SIZE = 8 * 1024 * 1024
REPORT_KEY = "watchboundNativeMetadata"


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def decode(data):
    return json.loads(data, object_pairs_hook=unique_object)


def entries(node, prefix=""):
    for name, entry in node.get("files", {}).items():
        full = prefix + name
        if "files" in entry:
            yield from entries(entry, full + "/")
        else:
            yield full, entry


def integrity(data):
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(data).hexdigest(),
        "blockSize": BLOCK_SIZE,
        "blocks": [hashlib.sha256(data[i:i + BLOCK_SIZE]).hexdigest()
                   for i in range(0, len(data), BLOCK_SIZE)],
    }


def read_archive(raw):
    if len(raw) < 16:
        raise ValueError("Truncated ASAR")
    size_size, header_size, payload_size, json_size = struct.unpack("<IIII", raw[:16])
    padded_size = (json_size + 3) & ~3
    if (size_size != 4 or header_size != 8 + padded_size
            or payload_size != 4 + padded_size or 8 + header_size > len(raw)):
        raise ValueError("Unsupported ASAR pickle header")
    if any(raw[16 + json_size:8 + header_size]):
        raise ValueError("Nonzero ASAR header padding")
    return decode(raw[16:16 + json_size]), 8 + header_size


def patch(archive, report):
    if not stat.S_ISREG(archive.lstat().st_mode):
        raise ValueError("ASAR must be a regular file")
    raw = archive.read_bytes()
    header, payload_start = read_archive(raw)
    files = dict(entries(header))
    native_candidates = [name for name in files
                         if name.startswith("node_modules/@gadicc/watchbound-node-")
                         and name.endswith(".node")]
    if native_candidates != [NATIVE] or MANIFEST not in files:
        raise ValueError("Expected exactly the pinned x64 Watchbound native package")
    native_entry, manifest_entry = files[NATIVE], files[MANIFEST]
    original_integrity = {
        "algorithm": "SHA256", "hash": ORIGINAL_SHA256,
        "blockSize": BLOCK_SIZE, "blocks": [ORIGINAL_SHA256],
    }
    if (native_entry.get("unpacked") is not True or "offset" in native_entry
            or "link" in native_entry or native_entry.get("size") != ORIGINAL_SIZE
            or native_entry.get("integrity") != original_integrity):
        raise ValueError("Watchbound native metadata drifted or was already repaired")
    if manifest_entry.get("unpacked") or "link" in manifest_entry:
        raise ValueError("Watchbound manifest must remain packed")
    manifest_offset = manifest_entry.get("offset")
    manifest_size = manifest_entry.get("size")
    if (not isinstance(manifest_offset, str) or not manifest_offset.isdecimal()
            or type(manifest_size) is not int or manifest_size <= 0):
        raise ValueError("Invalid Watchbound manifest range")
    start = payload_start + int(manifest_offset)
    end = start + manifest_size
    if end > len(raw):
        raise ValueError("Truncated Watchbound manifest")
    for name, entry in files.items():
        if name == MANIFEST or entry.get("unpacked") or "offset" not in entry:
            continue
        other_start = payload_start + int(entry["offset"])
        other_end = other_start + int(entry["size"])
        if start < other_end and other_start < end:
            raise ValueError("Another packed asset overlaps the Watchbound manifest")
    manifest_bytes = raw[start:end]
    if manifest_entry.get("integrity") != integrity(manifest_bytes):
        raise ValueError("Watchbound manifest integrity mismatch")
    manifest = decode(manifest_bytes)
    metadata = manifest.get("watchbound", {})
    if (manifest.get("name") != "@gadicc/watchbound-node-linux-x64-gnu"
            or manifest.get("version") != "2.1.2"
            or manifest.get("main") != "./watchbound.linux-x64-gnu.node"
            or metadata.get("delivery") != "target-native-package"
            or metadata.get("target") != "linux-x64-gnu"
            or metadata.get("architecture") != "x64"
            or metadata.get("libc") != "glibc"
            or metadata.get("binary") != "watchbound.linux-x64-gnu.node"
            or metadata.get("nativeSha256") != ORIGINAL_SHA256):
        raise ValueError("Watchbound manifest contract drifted")

    # Reject symlink traversal at every level of the unpacked native path.
    unpacked = Path(str(archive) + ".unpacked")
    native_path = unpacked
    if not stat.S_ISDIR(unpacked.lstat().st_mode):
        raise ValueError("Unpacked root must be a regular directory")
    for component in Path(NATIVE).parts:
        native_path = native_path / component
        mode = native_path.lstat().st_mode
        if component == Path(NATIVE).name:
            if not stat.S_ISREG(mode):
                raise ValueError("Watchbound native payload must be a regular file")
        elif not stat.S_ISDIR(mode):
            raise ValueError("Watchbound native path must contain only directories")
    native_stat = native_path.stat()
    if not 0 < native_stat.st_size <= MAX_NATIVE_SIZE:
        raise ValueError("Watchbound native size exceeds the loader contract")
    native_bytes = native_path.read_bytes()
    if len(native_bytes) != native_stat.st_size:
        raise ValueError("Watchbound native size changed while reading")
    # ELF64, little endian, version 1, ET_DYN, EM_X86_64. Actual bytes are the
    # trusted build's patchelf output, never fetched or altered by this script.
    if (len(native_bytes) < 64 or native_bytes[:7] != b"\x7fELF\x02\x01\x01"
            or struct.unpack_from("<HH", native_bytes, 16) != (3, 62)):
        raise ValueError("Watchbound native payload is not an x64 shared ELF")
    updated_integrity = integrity(native_bytes)
    if updated_integrity["hash"] == ORIGINAL_SHA256:
        raise ValueError("Watchbound native payload was not relocated")
    digest_pattern = re.compile(rb'("nativeSha256"\s*:\s*")([a-f0-9]{64})(")')
    matches = list(digest_pattern.finditer(manifest_bytes))
    if len(matches) != 1 or matches[0].group(2).decode() != ORIGINAL_SHA256:
        raise ValueError("Expected one nativeSha256 digest in Watchbound manifest")
    match = matches[0]
    changed_manifest = (manifest_bytes[:match.start(2)]
                        + updated_integrity["hash"].encode()
                        + manifest_bytes[match.end(2):])
    assert len(changed_manifest) == len(manifest_bytes)

    # Read and validate the prior composer report before writing anything.
    if report.exists() or report.is_symlink():
        if not stat.S_ISREG(report.lstat().st_mode):
            raise ValueError("Local mods report must be a regular file")
        report_data = decode(report.read_bytes())
        if not isinstance(report_data, dict) or REPORT_KEY in report_data:
            raise ValueError("Unexpected or already repaired local mods report")
    else:
        report_data = {}
    native_entry["size"] = len(native_bytes)
    native_entry["integrity"] = updated_integrity
    manifest_entry["integrity"] = integrity(changed_manifest)
    json_bytes = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
    padded_size = (len(json_bytes) + 3) & ~3
    prefix = struct.pack("<IIII", 4, 8 + padded_size, 4 + padded_size, len(json_bytes))
    prefix += json_bytes + b"\0" * (padded_size - len(json_bytes))
    payload = bytearray(raw[payload_start:])
    payload[int(manifest_offset):int(manifest_offset) + manifest_size] = changed_manifest
    report_data[REPORT_KEY] = {
        "version": "2.1.2", "target": "linux-x64-gnu",
        "nativeAsset": NATIVE, "manifestAsset": MANIFEST,
        "beforeSize": ORIGINAL_SIZE, "afterSize": len(native_bytes),
        "beforeSha256": ORIGINAL_SHA256, "afterSha256": updated_integrity["hash"],
        "nativePayloadChanged": False,
    }
    replacements = []
    try:
        for destination, content in [
            (archive, prefix + payload),
            (report, (json.dumps(report_data, indent=2) + "\n").encode()),
        ]:
            with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
                temporary.write(content)
                temporary_path = Path(temporary.name)
            replacements.append((temporary_path, destination))
            mode = destination.stat().st_mode & 0o777 if destination.exists() else 0o644
            temporary_path.chmod(mode)
        for temporary_path, destination in replacements:
            os.replace(temporary_path, destination)
    finally:
        for temporary_path, _ in replacements:
            temporary_path.unlink(missing_ok=True)
    print(f"Repaired Watchbound native metadata: {NATIVE}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch-watchbound-metadata.py app.asar report.json")
    patch(Path(sys.argv[1]), Path(sys.argv[2]))
