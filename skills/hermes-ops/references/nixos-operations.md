# NixOS operations

## Inspect

```bash
git -C /home/cjm/dotfiles status --short
git -C /home/cjm/dotfiles diff --stat
nh os generations
readlink -f /run/current-system
```

Read the relevant module and its import path before editing. Existing changes in
the worktree belong to Carter unless this task created them.

## Validate and build

Format only files touched by the task:

```bash
nixfmt /home/cjm/dotfiles/path/to/file.nix
nix flake check /home/cjm/dotfiles --no-build --show-trace
nh os build /home/cjm/dotfiles
```

Do not keep or commit a `result` symlink. A successful evaluation is not a
successful build; report the final `nh os build` observation.

## Switch and verify

Carter performs the privileged switch with `nrs`. Afterward, re-check every
changed surface:

```bash
systemctl --user daemon-reload
systemctl --user is-active hermes-gateway.service
systemctl --user list-timers --all --no-pager
systemctl --failed --no-pager
```

For a package, run its version/help command from the activated profile. For a
unit, inspect both `systemctl show` and a bounded journal. For a web endpoint,
fetch it again after the switch.

## Rollback

List generations and identify the exact target before proposing a rollback.
Never delete generations or run a destructive reset as a debugging shortcut.
If rollback is required, give Carter the exact generation and let him perform
the privileged operation.
