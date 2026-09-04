"""Invalidate both bundled-plugin caches when the local Linux backend changes."""
import hashlib
import json
from pathlib import Path
import sys


def version_plugin(root: Path, report_path: Path):
    manifest_path = root / ".codex-plugin/plugin.json"
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("name") != "computer-use" or manifest.get("version") != "0.1.2-linux-alpha2":
        raise ValueError("Unknown Computer Use manifest; review cache versioning before updating")
    digest = hashlib.sha256()
    for relative in (".mcp.json", "bin/codex-computer-use-linux", "bin/codex-computer-use-cosmic"):
        payload = (root / relative).read_bytes()
        digest.update(relative.encode() + b"\0")
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
    manifest["version"] += ".cjm.h" + digest.hexdigest()[:16]
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    report = json.loads(report_path.read_text())
    report["computerUsePlugin"] = {
        "version": manifest["version"],
        "backendContentSha256": digest.hexdigest(),
        "reason": "Invalidate app staging and installed-plugin caches for rebuilt Linux helpers",
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("Computer Use plugin cache version:", manifest["version"])


if __name__ == "__main__":
    version_plugin(Path(sys.argv[1]), Path(sys.argv[2]))
