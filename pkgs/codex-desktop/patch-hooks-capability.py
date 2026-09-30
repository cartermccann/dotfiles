"""Do not send lifecycle hook RPCs to the durable/cloud app-server.

The shared query serves both settings and the background composer. Preserve
local/connected-host routing and errors; show an explicit unsupported panel
instead of treating a cloud task as an empty local hooks configuration.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys

ID = r"[A-Za-z_$][\w$]*"
MARKER = "/*cjmHooksCapability*/"
REASON = "Lifecycle hooks are unavailable on cloud tasks. Select a local or connected coding host to manage hooks."
REPORT_KEY = "hooksHostCapability"


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


def one(pattern, source, contract):
    found = list(re.finditer(pattern, source))
    if len(found) != 1:
        raise ValueError(f"Expected exactly one {contract}, found {len(found)}")
    return found[0]


def replace(source, old, new, contract):
    if source.count(old) != 1:
        raise ValueError(f"{contract} contract changed")
    return source.replace(old, new, 1)


def durable_predicate(shared, source):
    # Select the host-ID predicate adjacent to encoded host-ID helpers, not an
    # unrelated equivalent predicate or the community's stubbed cloud helper.
    match = one(r"function (" + ID + r")\(e\)\{return e===(" + ID +
                r")\}function " + ID + r"\(e\)\{return`\$\{" + ID +
                r"\}\$\{encodeURIComponent\(e\)\}`\}", shared, "durable host predicate")
    function, constant = match.groups()
    one(r"(?<![\w$])" + re.escape(constant) + r"=`durable`", shared, "durable host constant")
    exported = one(r"(?<![\w$])" + re.escape(function) + r" as (" + ID + r")(?=[,}])", shared,
                   "durable predicate export").group(1)
    imports = one(r'import\{([^}]+)\}from"\./app-shared-[^"/]+\.js"', source,
                  "shared predicate import block").group(1)
    return one(r"(?<![\w$])" + re.escape(exported) + r" as (" + ID + r")(?=[,}]|$)", imports,
               "durable predicate import").group(1)


def patch_query(source, shared):
    if MARKER in source:
        raise ValueError("Hooks capability patch already present")
    predicate = durable_predicate(shared, source)
    query = one(r"\(\{hostId:e,cwds:t\},\{scope:n\}\)=>\(\{queryKey:\[\.\.\." + ID +
                r",e,t\],queryFn:\(\)=>\{if\(t==null\|\|t.length===0\)throw Error\(`Cannot list hooks without project roots`\);return " +
                ID + r"\(n,e\).sendRequest\(`hooks/list`,\{cwds:t\}\)\},staleTime:" + ID +
                r"\.FIVE_MINUTES,refetchOnMount:!0,enabled:t!=null&&t.length>0\}\)", source,
                "shared hooks query")
    original = query.group()
    changed = replace(original, "queryFn:()=>{", "queryFn:()=>{" + MARKER +
                      f"if({predicate}(e))return{{data:[],unsupportedReason:`{REASON}`}};", "query body")
    changed = replace(changed, "enabled:t!=null&&t.length>0", f"enabled:{predicate}(e)||t!=null&&t.length>0",
                      "query enablement")
    return source[:query.start()] + changed + source[query.end():]


def function_source(source, name):
    match = one(r"function " + re.escape(name) + r"\(e?\)\{", source, "panel function")
    # These minified functions contain arrow functions but no nested named
    # declarations. Fail closed if this upstream boundary contract changes.
    end = source.find("}function ", match.end())
    if end < 0:
        end = source.find("}var ", match.end())
    if end < 0:
        raise ValueError("Panel function boundary changed")
    return match.start(), end + 1, source[match.start():end + 1]


def patch_panel(source):
    if MARKER in source:
        raise ValueError("Hooks capability patch already present")
    exported = one(r"export\{(" + ID + r") as HooksSettings\}", source, "HooksSettings export").group(1)
    start, end, component = function_source(source, exported)
    rendered = one(r"q=\(0," + ID + r"\.jsx\)\((" + ID + r"),\{entries:H,hostId:d,", component,
                   "HooksSettings panel render").group(1)
    reason = "cjmHooksUnsupportedReason"
    component = replace(component, ".c)(47)", ".c)(48)", "settings memo size")
    component = replace(component, "let R=L,z;", f"let {reason}=M.data?.unsupportedReason,R=L,z;", "settings marker")
    component = replace(component, "L=()=>{M.refetch().then", "L=()=>{if(M.data?.unsupportedReason!=null)return;M.refetch().then",
                        "refresh guard")
    component = replace(component, "e.isSuccess&&(await", "e.isSuccess&&e.data?.unsupportedReason==null&&(await",
                        "refresh success")
    component = replace(component, "e[45]!==U?(q=", f"e[45]!==U||e[47]!=={reason}?(q=", "settings memo condition")
    component = replace(component, "{entries:H,hostId:d,", f"{{unsupportedReason:{reason},entries:H,hostId:d,", "settings props")
    component = replace(component, "e[45]=U,e[46]=q", f"e[45]=U,e[47]={reason},e[46]=q", "settings memo assignment")
    source = source[:start] + component + source[end:]
    start, end, panel = function_source(source, rendered)
    panel = replace(panel, ".c)(72)", ".c)(73)", "panel memo size")
    panel = replace(panel, "{entries:n,hostId:r,", f"{{unsupportedReason:{reason},entries:n,hostId:r,", "panel props")
    panel = replace(panel, "let V=u==null", f"let V={reason}!=null||u==null", "refresh disabled")
    panel = replace(panel, "t[49]!==A?(G=", f"t[49]!==A||t[72]!=={reason}?(G=", "panel memo condition")
    panel = replace(panel, "G=u==null&&a?ne:", f"G={reason}!=null?(0,$.jsx)(`p`,{{role:`status`,className:`text-sm text-secondary`,children:{reason}}}):u==null&&a?ne:",
                    "unsupported panel")
    panel = replace(panel, "t[49]=A,t[50]=G", f"t[49]=A,t[72]={reason},t[50]=G", "panel memo assignment")
    panel = replace(panel, "let K=d!=null&&(s||O!=null)", f"let K={reason}==null&&d!=null&&(s||O!=null)", "source dialog")
    return source[:start] + MARKER + panel + source[end:]


def read_archive(raw, verify_names=()):
    if len(raw) < 16:
        raise ValueError("Truncated ASAR header")
    size_size, header_size, payload_size, json_size = struct.unpack("<IIII", raw[:16])
    base = 8 + header_size
    if (size_size != 4 or payload_size + 4 != header_size or json_size > header_size - 8
            or header_size < 8 or base > len(raw) or header_size % 4):
        raise ValueError("Unsupported ASAR pickle header")
    header = json.loads(raw[16:16 + json_size])
    if not isinstance(header, dict) or not isinstance(header.get("files"), dict):
        raise ValueError("Invalid ASAR file tree")
    spans = []
    for name, entry in entries(header):
        if entry.get("unpacked") or "link" in entry:
            continue
        if not isinstance(entry.get("offset"), str) or not entry["offset"].isdigit() or type(entry.get("size")) is not int:
            raise ValueError("Invalid ASAR payload entry")
        off, size = int(entry["offset"]), entry["size"]
        if size < 0 or off + size > len(raw) - base:
            raise ValueError("ASAR payload out of bounds")
        spans.append((off, off + size))
        digest = entry.get("integrity")
        if name in verify_names:
            if digest is None:
                raise ValueError(f"Hooks asset integrity missing: {name}")
            block = digest.get("blockSize") if isinstance(digest, dict) else None
            if type(block) is not int or block <= 0 or integrity(raw[base + off:base + off + size], block) != digest:
                raise ValueError(f"Original asset integrity mismatch: {name}")
    spans.sort()
    if any(right[0] < left[1] for left, right in zip(spans, spans[1:])):
        raise ValueError("Overlapping ASAR payload entries")
    return header, base


def patch(archive, report):
    metadata = json.loads(report.read_text()) if report.exists() else {}
    if not isinstance(metadata, dict):
        raise ValueError("Local modifications report must be a JSON object")
    if REPORT_KEY in metadata:
        raise ValueError("Hooks capability report already present")
    raw = archive.read_bytes()
    header, base = read_archive(raw)
    assets = {}
    for name, entry in entries(header):
        if entry.get("unpacked") or "offset" not in entry or not name.startswith("webview/assets/") or not name.endswith(".js"):
            continue
        off = int(entry["offset"])
        content = raw[base + off:base + off + entry["size"]].decode()
        if MARKER in content:
            raise ValueError("Hooks capability patch already present")
        assets[name] = (entry, content)
    query_name = [name for name, (_, source) in assets.items() if "`Cannot list hooks without project roots`" in source]
    panel_name = [name for name, (_, source) in assets.items() if re.search(r"export\{" + ID + r" as HooksSettings\}", source)]
    if len(query_name) != 1 or len(panel_name) != 1:
        raise ValueError("Expected exactly one hooks query asset and settings asset")
    query_name, panel_name = query_name[0], panel_name[0]
    shared_name = one(r'from"\./(app-shared-[^"/]+\.js)"', assets[query_name][1], "shared asset import").group(1)
    shared = assets.get("webview/assets/" + shared_name)
    if shared is None:
        raise ValueError("Shared host predicate asset missing")
    read_archive(raw, (query_name, panel_name))
    changes = {query_name: patch_query(assets[query_name][1], shared[1]).encode(),
               panel_name: patch_panel(assets[panel_name][1]).encode()}
    replacements, evidence = [], {}
    for name, changed in changes.items():
        entry, _ = assets[name]
        digest = entry.get("integrity")
        if not digest:
            raise ValueError("Hooks asset integrity missing")
        off, size = int(entry["offset"]), entry["size"]
        replacements.append((off, size, changed))
        entry["size"] = len(changed)
        entry["integrity"] = integrity(changed, digest["blockSize"])
        evidence[name] = {"beforeSha256": digest["hash"], "afterSha256": entry["integrity"]["hash"],
                          "addedBytes": len(changed) - size}
    replacements.sort()
    for name, entry in entries(header):
        if entry.get("unpacked") or "offset" not in entry:
            continue
        original = int(entry["offset"])
        entry["offset"] = str(original + sum(len(changed) - size for off, size, changed in replacements if off < original))
    payload, cursor = [], 0
    for off, size, changed in replacements:
        payload.extend((raw[base + cursor:base + off], changed))
        cursor = off + size
    payload.append(raw[base + cursor:])
    encoded = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
    padded = (len(encoded) + 3) & ~3
    result = struct.pack("<IIII", 4, 8 + padded, 4 + padded, len(encoded)) + encoded + b"\0" * (padded - len(encoded)) + b"".join(payload)
    read_archive(result, changes)  # Validate bounds globally and changed digests before writing.
    metadata[REPORT_KEY] = {"assets": evidence, "policy": "compatibility workaround for currently unsupported durable hooks API; retain host-scoped local and connected RPCs",
                            "liveSettingsVerificationRequired": True}
    temporary = archive.with_suffix(".asar.hooks-new")
    temporary.write_bytes(result)
    temporary.chmod(archive.stat().st_mode & 0o777)
    os.replace(temporary, archive)
    report.write_text(json.dumps(metadata, indent=2) + "\n")
    print("Preserved host-scoped hooks with explicit cloud-task unsupported state")


if __name__ == "__main__":
    patch(Path(sys.argv[1]), Path(sys.argv[2]))
