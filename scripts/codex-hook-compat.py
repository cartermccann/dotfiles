#!/usr/bin/env python3
"""Repair Stripe's command/args hook format for Codex's command-only runner."""

import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile


SCRIPT = re.compile(
    r"\$\{CLAUDE_PLUGIN_ROOT\}/scripts/lifecycle/"
    r"(?:sessionStart|postToolUse|postToolUseFailure|postToolBatch|userPromptSubmit)\.mjs"
)


def repair(path: Path) -> int:
    if path.is_symlink() or not path.is_file():
        return 0
    original = path.read_bytes()
    data = json.loads(original)
    changed = 0
    for groups in data.get("hooks", {}).values():
        for group in groups:
            for hook in group.get("hooks", []):
                args = hook.get("args")
                if (
                    hook.get("type") == "command"
                    and hook.get("command") == "node"
                    and isinstance(args, list)
                    and len(args) == 1
                    and isinstance(args[0], str)
                    and SCRIPT.fullmatch(args[0])
                ):
                    hook["command"] = f'node "{args[0]}"'
                    del hook["args"]
                    changed += 1
    if not changed:
        return 0
    backup = path.with_name("hooks.json.codex-compat-backup")
    # Retain the first upstream manifest; never overwrite an existing backup.
    try:
        with backup.open("xb") as handle:
            handle.write(original)
        backup.chmod(path.stat().st_mode & 0o777)
    except FileExistsError:
        pass
    replacement = json.dumps(data, indent=2) + "\n"
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".codex-hook-", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(replacement.encode())
            os.fchmod(handle.fileno(), path.stat().st_mode & 0o777)
        # Do not overwrite a plugin refresh that raced this repair.
        if path.read_bytes() != original:
            raise RuntimeError(f"plugin manifest changed during repair: {path}")
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")))
    args = parser.parse_args()
    stripe = args.codex_home / "plugins/cache/claude-plugins-official/stripe"
    for path in sorted(stripe.glob("*/hooks/hooks.json")):
        try:
            count = repair(path)
        except (OSError, ValueError, TypeError, AttributeError, RuntimeError) as error:
            print(f"Codex Stripe hook repair skipped {path}: {error}", file=sys.stderr)
            continue
        if count:
            print(f"Repaired {count} Stripe hook commands in {path}. Review their trust in Codex Settings > Hooks.")


if __name__ == "__main__":
    main()
