"""Use the existing compact overlay viewport on Linux; reject source drift.

The upstream native draw canvas spans twice the tallest monitor for animation.
Linux exposes that canvas as a fixed-size window. Keep native content layout,
but use upstream's bounded viewport calculation for the Linux window bounds.
This affects only the shared pet/voice overlay geometry, not voice availability.
"""

import hashlib
import json
import os
from pathlib import Path
import struct
import sys

MARKER = b"/*cjmLinuxOverlayBounds*/"
START = b"function noe({anchor:e,constrainNativeDrawWindowToDisplay:t=!1,"
END = b"function Jp(e,t)"
OLD = b"if(_){let e=o??w;"
NEW = b"if(_&&process.platform!==`linux`" + MARKER + b"){let e=o??w;"
CONTRACTS = (
    b"nativeDrawDisplayHeightPx:c=n.height",
    b"j=roe({anchor:e,displayBounds:n,nativeDrawDisplayHeightPx:c,viewportWidth:g.width})",
    b"let e=soe({anchor:w,displayBounds:n,mode:i,placement:E,bottomReserve:y,viewport:O})",
    b"mascot:$p(w,j)", b"tray:A==null?null:$p(A,j)", b"windowBounds:j",
)


def entries(node, prefix=""):
    for name, entry in node.get("files", {}).items():
        full = prefix + name
        if "files" in entry:
            yield from entries(entry, full + "/")
        else:
            yield full, entry


def integrity(data, block_size):
    return {"algorithm": "SHA256", "hash": hashlib.sha256(data).hexdigest(),
            "blockSize": block_size,
            "blocks": [hashlib.sha256(data[i:i + block_size]).hexdigest()
                       for i in range(0, len(data), block_size)]}


def read_archive(raw):
    size_size, header_size, payload_size, json_size = struct.unpack("<IIII", raw[:16])
    if size_size != 4 or payload_size + 4 != header_size:
        raise ValueError("Unsupported ASAR pickle header")
    return json.loads(raw[16:16 + json_size]), 8 + header_size


def patch_source(content):
    if MARKER in content:
        raise ValueError("Linux overlay patch already present")
    if content.count(START) != 1:
        raise ValueError("Expected exactly one overlay layout function")
    start = content.index(START)
    end = content.find(END, start)
    if end < 0:
        raise ValueError("Overlay function boundary changed")
    function = content[start:end]
    if function.count(OLD) != 1 or any(function.count(c) != 1 for c in CONTRACTS):
        raise ValueError("Overlay geometry contract changed")
    return content[:start] + function.replace(OLD, NEW) + content[end:]


def patch(archive, report):
    metadata = json.loads(report.read_text()) if report.exists() else {}
    if not isinstance(metadata, dict):
        raise ValueError("Local modifications report must be a JSON object")
    if "linuxOverlayBounds" in metadata:
        raise ValueError("Linux overlay report already present")
    raw = archive.read_bytes()
    header, base = read_archive(raw)
    found = []
    for name, entry in entries(header):
        if entry.get("unpacked") or "offset" not in entry:
            continue
        if not name.startswith(".vite/build/main-") or not name.endswith(".js"):
            continue
        off = int(entry["offset"])
        content = raw[base + off:base + off + entry["size"]]
        if MARKER in content:
            raise ValueError("Linux overlay patch already present")
        if START in content:
            found.append((name, entry, content, off))
    if len(found) != 1:
        raise ValueError(f"Expected one main overlay asset, found {len(found)}")
    name, entry, content, offset = found[0]
    old_size = entry["size"]
    old_integrity = entry.get("integrity", {})
    block_size = old_integrity.get("blockSize", 0)
    if type(block_size) is not int or block_size <= 0 or integrity(content, block_size) != old_integrity:
        raise ValueError("Original main asset integrity mismatch")
    changed = patch_source(content)
    delta = len(changed) - old_size
    # Preserve every other packed byte and unpacked/link entry. Only offsets
    # after the expanded main asset need to move.
    for other_name, other in entries(header):
        if other_name == name or other.get("unpacked") or "offset" not in other:
            continue
        position = int(other["offset"])
        if position >= offset + old_size:
            other["offset"] = str(position + delta)
        elif position + other["size"] > offset:
            raise ValueError("Overlapping ASAR payload entries")
    entry["size"] = len(changed)
    entry["integrity"] = integrity(changed, block_size)
    encoded = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
    padded = (len(encoded) + 3) & ~3
    prefix = struct.pack("<IIII", 4, 8 + padded, 4 + padded, len(encoded))
    payload = raw[base:base + offset] + changed + raw[base + offset + old_size:]
    result = prefix + encoded + b"\0" * (padded - len(encoded)) + payload
    temporary = archive.with_suffix(".asar.overlay-new")
    temporary.write_bytes(result)
    temporary.chmod(archive.stat().st_mode & 0o777)
    os.replace(temporary, archive)
    metadata["linuxOverlayBounds"] = {
        "asset": name, "beforeSha256": old_integrity["hash"],
        "afterSha256": entry["integrity"]["hash"], "addedBytes": delta,
        "policy": "native content with bounded existing viewport on Linux",
        "liveVisualVerificationRequired": True}
    report.write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Preserved compact Linux pet/voice overlay bounds: {name}")


if __name__ == "__main__":
    patch(Path(sys.argv[1]), Path(sys.argv[2]))
