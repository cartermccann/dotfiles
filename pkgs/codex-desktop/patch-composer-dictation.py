"""Preserve Carter's composer dictation gate override; reject upstream drift.

Only the feature gate's value changes. Media APIs, ChatGPT authentication and
loading checks remain upstream-owned. ASAR offsets and unpacked files remain
unchanged; regenerate the modified entry's integrity and the pickle header.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys

MARKER = b"/*cjmDictation*/"
IDENT = rb"[A-Za-z_$][\w$]*"
CONTRACT = re.compile(
    rb"let (?P<loading>" + IDENT + rb")=(?P<get>" + IDENT
    + rb")\((?P<loading_atom>" + IDENT + rb"),`4100906017`\),"
    + rb"(?P<gate>" + IDENT + rb")=(?P<value>(?P=get)\("
    + IDENT + rb",`4100906017`\)),\{authLoading:"
    + IDENT + rb",authMethod:" + IDENT + rb"\}="
)


def entries(node, prefix=""):
    for name, entry in node.get("files", {}).items():
        full = prefix + name
        if "files" in entry:
            yield from entries(entry, full + "/")
        else:
            yield full, entry


def integrity(data, block_size):
    return {
        "algorithm": "SHA256",
        "hash": hashlib.sha256(data).hexdigest(),
        "blockSize": block_size,
        "blocks": [hashlib.sha256(data[i:i + block_size]).hexdigest()
                   for i in range(0, len(data), block_size)],
    }


def patch(archive, report):
    raw = archive.read_bytes()
    size_size, header_size, payload_size, json_size = struct.unpack("<IIII", raw[:16])
    if size_size != 4 or payload_size + 4 != header_size:
        raise ValueError("Unsupported ASAR pickle header")
    header = json.loads(raw[16:16 + json_size])
    payload_start = 8 + header_size
    matches = []
    for name, entry in entries(header):
        if not name.startswith("webview/assets/") or not name.endswith(".js") or entry.get("unpacked"):
            continue
        offset = payload_start + int(entry["offset"])
        content = raw[offset:offset + entry["size"]]
        if MARKER in content:
            raise ValueError("Dictation override already present; build from pristine input")
        for match in CONTRACT.finditer(content):
            if b"navigator?.mediaDevices?.getUserMedia" not in content[max(0, match.start() - 250):match.start()]:
                continue
            tail = content[match.end():match.end() + 220]
            if b"isCapable:" not in tail or b"===`chatgpt`" not in tail:
                continue
            matches.append((name, entry, offset, content, match))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one composer dictation contract, found {len(matches)}")
    name, entry, offset, content, match = matches[0]
    old_integrity = entry.get("integrity", {})
    block_size = old_integrity.get("blockSize", 0)
    if not isinstance(block_size, int) or block_size <= 0 or integrity(content, block_size) != old_integrity:
        raise ValueError("Original dictation asset integrity mismatch")
    replacement = b"!0" + MARKER
    width = len(match.group("value"))
    if len(replacement) > width:
        raise ValueError("Gate expression too short for size-preserving patch")
    replacement = replacement.ljust(width, b" ")
    changed = content[:match.start("value")] + replacement + content[match.end("value"):]
    assert len(changed) == len(content)
    entry["integrity"] = integrity(changed, block_size)
    json_bytes = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
    padded_size = (len(json_bytes) + 3) & ~3
    prefix = struct.pack("<IIII", 4, 8 + padded_size, 4 + padded_size, len(json_bytes))
    prefix += json_bytes + b"\0" * (padded_size - len(json_bytes))
    payload = bytearray(raw[payload_start:])
    relative_offset = offset - payload_start
    payload[relative_offset:relative_offset + len(changed)] = changed
    result = prefix + payload
    temporary = archive.with_suffix(".asar.dictation-new")
    temporary.write_bytes(result)
    temporary.chmod(archive.stat().st_mode & 0o777)
    os.replace(temporary, archive)
    report.write_text(json.dumps({
        "composerDictation": {"gate": "4100906017", "asset": name,
                              "beforeSha256": old_integrity["hash"],
                              "afterSha256": entry["integrity"]["hash"],
                              "authenticationRequired": "chatgpt"},
        "upstreamFeatures": ["codex-micro", "computer-use-linux", "directory-only-working-tree-watch"],
    }, indent=2) + "\n")
    print(f"Preserved composer dictation override: {name}")


if __name__ == "__main__":
    patch(Path(sys.argv[1]), Path(sys.argv[2]))
