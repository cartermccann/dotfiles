#!/usr/bin/env python3
"""Refresh only Codex release pins, verify downloads, and build without switching."""

import argparse
import base64
import copy
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile


DESKTOP = "codex-desktop-linux"
DESKTOP_REPO = "ilysenko/codex-desktop-linux"
CLI_SOURCE = "pkgs/codex/sources.json"
TARGETS = {
    "x86_64-linux": "x86_64-unknown-linux-musl",
    "aarch64-linux": "aarch64-unknown-linux-musl",
}
PIN = re.compile(
    r'(codex-desktop-linux\.url\s*=\s*"github:ilysenko/codex-desktop-linux/)'
    r'([0-9a-f]{40})(";)'
)


def run(*args, cwd=None, capture=False):
    result = subprocess.run(args, cwd=cwd, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def fetch_json(url):
    return json.loads(run(
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--retry", "2", "--connect-timeout", "10", "--max-time", "60",
        url, capture=True,
    ))


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise ValueError(f"Unexpected stable version: {value!r}")
    return tuple(map(int, value.split(".")))


def release_sources(current, release, download=False):
    tag = release["tag_name"]
    if release["draft"] or release["prerelease"] or not tag.startswith("rust-v"):
        raise ValueError("Expected an official stable CLI release")
    latest = tag.removeprefix("rust-v")
    if version(latest) < version(current["version"]):
        raise ValueError("Refusing a CLI downgrade")
    if set(current["bundles"]) != set(TARGETS):
        raise ValueError("Unexpected CLI architecture mapping")
    sources = copy.deepcopy(current)
    sources["version"] = latest
    for system, target in TARGETS.items():
        if sources["bundles"][system]["target"] != target:
            raise ValueError(f"Unexpected CLI target for {system}")
        name = f"codex-package-{target}.tar.zst"
        assets = [asset for asset in release["assets"] if asset["name"] == name]
        if len(assets) != 1:
            raise ValueError(f"Expected exactly one release asset: {name}")
        asset = assets[0]
        url = f"https://github.com/openai/codex/releases/download/{tag}/{name}"
        if asset["browser_download_url"] != url:
            raise ValueError(f"Unexpected asset URL: {name}")
        digest = asset.get("digest")
        if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError(f"Missing SHA-256 digest: {name}")
        expected = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode()
        if download and current["bundles"][system]["hash"] != expected:
            print(f"Verifying {name}...", flush=True)
            actual = json.loads(run(
                "nix", "store", "prefetch-file", "--json", "--hash-type", "sha256",
                url, capture=True,
            ))["hash"]
            if actual != expected:
                raise ValueError(f"Release digest mismatch: {name}")
        sources["bundles"][system]["hash"] = expected
    return sources


def check_lock_scope(before, after):
    """Other root inputs must keep their exact dependency graph."""
    def graph(lock, key):
        seen = {}

        def resolve(reference, resolving=()):
            if isinstance(reference, str):
                return reference
            if not isinstance(reference, list):
                raise ValueError("Unexpected flake lock reference")
            path = tuple(reference)
            if path in resolving:
                raise ValueError("Cyclic follows reference in flake lock")
            node = lock["root"]
            for component in path:
                dependency = lock["nodes"][node]["inputs"][component]
                node = resolve(dependency, resolving + (path,))
            return node

        def visit(node):
            node = resolve(node)
            if node in seen:
                return
            seen[node] = lock["nodes"][node]
            for dependency in seen[node].get("inputs", {}).values():
                visit(dependency)

        visit(key)
        return seen

    old = before["nodes"][before["root"]]["inputs"]
    new = after["nodes"][after["root"]]["inputs"]
    if old.keys() != new.keys():
        raise ValueError("Lock update changed the root input set")
    for name in old:
        if name != DESKTOP and (old[name] != new[name] or graph(before, old[name]) != graph(after, new[name])):
            raise ValueError(f"Lock update touched unrelated input: {name}")


def validate(repo):
    for name in ("test-dictation-patch.py", "test-overlay-bounds.py", "test-hooks-capability.py", "test-watchbound-metadata.py"):
        run(sys.executable, str(repo / "pkgs/codex-desktop" / name), cwd=repo)
    run("nh", "os", "build", str(repo), "--no-nom", cwd=repo)


def atomic_write(path, data, expected):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".codex-update-", delete=False) as handle:
            temporary = Path(handle.name)
            os.fchmod(handle.fileno(), path.stat().st_mode & 0o777)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        if path.read_bytes() != expected:
            raise ValueError(f"Preserved concurrent edit to {path}; rerun the update")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def apply_and_build(repo, originals, candidates):
    changed = {name: data for name, data in candidates.items() if data != originals[name]}
    if any((repo / name).read_bytes() != data for name, data in originals.items()):
        raise ValueError("Codex pins changed during preparation; rerun the update")
    written = {}
    try:
        for name, data in changed.items():
            written[name] = data
            atomic_write(repo / name, data, originals[name])
        validate(repo)
        if any((repo / name).read_bytes() != data for name, data in candidates.items()):
            raise ValueError("Codex pins changed during validation; rerun the update")
    except BaseException:
        for name, data in written.items():
            try:
                current = (repo / name).read_bytes()
                if current == data:
                    atomic_write(repo / name, originals[name], data)
                elif current != originals[name]:
                    print(f"Preserved concurrent edit to {name}; inspect it before retrying.", file=sys.stderr)
            except (OSError, ValueError) as error:
                print(f"Could not restore {name}: {error}", file=sys.stderr)
        print("Update failed; restored this command's pin changes where safe.", file=sys.stderr)
        raise
    print("Build passed. Run nrs in your terminal to apply, then restart Codex.")


def update(repo, args):
    names = (CLI_SOURCE, "flake.nix", "flake.lock")
    originals = {name: (repo / name).read_bytes() for name in names}
    candidates = dict(originals)
    current = json.loads(originals[CLI_SOURCE])
    flake = originals["flake.nix"].decode()
    matches = list(PIN.finditer(flake))
    if len(matches) != 1:
        raise ValueError("Expected one explicit desktop revision in flake.nix")
    current_rev = matches[0][2]
    lock = json.loads(originals["flake.lock"])
    desktop_node = lock["nodes"][lock["nodes"][lock["root"]]["inputs"][DESKTOP]]
    if desktop_node["locked"]["rev"] != current_rev:
        raise ValueError("Desktop flake.nix and flake.lock revisions disagree")

    if not args.desktop_only:
        release = fetch_json("https://api.github.com/repos/openai/codex/releases/latest")
        sources = release_sources(current, release, download=not args.check)
        print(f"CLI: {current['version']} -> {sources['version']}", flush=True)
        if sources != current:
            candidates[CLI_SOURCE] = (json.dumps(sources, indent=2) + "\n").encode()

    if not args.cli_only:
        commit = fetch_json(f"https://api.github.com/repos/{DESKTOP_REPO}/commits/main")
        latest_rev = commit["sha"]
        if not isinstance(latest_rev, str) or not re.fullmatch(r"[0-9a-f]{40}", latest_rev):
            raise ValueError("Unexpected desktop source revision")
        pins_url = f"https://raw.githubusercontent.com/{DESKTOP_REPO}/{{}}/nix/upstream-linux-packages.json"
        previous = fetch_json(pins_url.format(current_rev))
        latest = previous if latest_rev == current_rev else fetch_json(pins_url.format(latest_rev))
        if version(latest["version"]) < version(previous["version"]):
            raise ValueError("Refusing a desktop downgrade")
        print(f"Desktop: {previous['version']} -> {latest['version']} "
              f"({current_rev[:12]} -> {latest_rev[:12]})", flush=True)
        if not args.check and latest_rev != current_rev:
            candidates["flake.nix"] = PIN.sub(lambda m: m[1] + latest_rev + m[3], flake).encode()
            with tempfile.TemporaryDirectory(prefix="codex-update-") as directory:
                staging = Path(directory)
                for name in ("flake.nix", "flake.lock"):
                    (staging / name).write_bytes(candidates[name])
                run("nix", "flake", "update", DESKTOP, "--flake", f"path:{staging}", cwd=staging)
                updated_lock = (staging / "flake.lock").read_bytes()
                check_lock_scope(lock, json.loads(updated_lock))
                candidates["flake.lock"] = updated_lock

    if args.check:
        print("Check only; no files changed or packages downloaded.")
        return
    print("Running patch tests and system build...", flush=True)
    apply_and_build(repo, originals, candidates)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.home() / "nix-config")
    parser.add_argument("--check", action="store_true", help="Only report current and latest pins")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--cli-only", action="store_true")
    group.add_argument("--desktop-only", action="store_true")
    args = parser.parse_args()
    repo = args.repo.expanduser().resolve()
    if args.check:
        update(repo, args)
        return
    lock_path = Path(run("git", "rev-parse", "--git-path", "codex-update.lock", cwd=repo, capture=True).strip())
    if not lock_path.is_absolute():
        lock_path = repo / lock_path
    with lock_path.open("w") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        update(repo, args)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(128 + signum))
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"codex-update: {error}", file=sys.stderr)
        sys.exit(1)
