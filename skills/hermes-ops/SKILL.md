---
name: hermes-ops
description: Inspect and operate Carter's NixOS workstation, systemd services and timers, Hermes gateway and cron, containers, Git projects, durable builds or tests, and normalized operational events. Use for machine health, service failures, Nix changes, project checks, long-running commands, deploy verification, or local-to-Telegram event routing.
---

# Hermes Ops

Operate the workstation as a real NixOS system. Inspect first, make reversible
changes directly, verify the observed result, and leave durable configuration in
`/home/cjm/dotfiles`.

## Operating loop

1. Establish scope: user or system service, repository, container, Hermes job,
   or whole workstation.
2. Capture current state. Run `scripts/ops-snapshot.sh` for broad incidents;
   use bounded commands for focused work.
3. Check the relevant reference before changing Nix, systemd, a long job, or an
   event-producing workflow.
4. Apply the smallest complete change. Preserve unrelated dirty worktree edits.
5. Run the project-specific check plus the live-state check. A process exit code
   alone is not verification.
6. Emit a local event for durable jobs or incidents. Add `--notify` only when
   Telegram delivery is part of the requested workflow.

## Route the task

- Machine overview or unclear incident: run `scripts/ops-snapshot.sh` and pass
  any relevant repository paths as arguments.
- NixOS/Home Manager build, generation, switch, or rollback: read
  `references/nixos-operations.md`.
- Unit failure, timer skip, gateway problem, journal analysis, or durable job:
  read `references/services-and-jobs.md`.
- Project check, deploy, Hermes cron trigger, or event routing: read
  `references/projects-and-events.md`.
- Long command: launch it with `scripts/run-and-notify.sh --name NAME -- CMD...`.
  Query the printed transient unit instead of holding an interactive shell open.
- Hermes cron by stable name: use `scripts/trigger-cron-by-name.sh NAME`; do not
  copy opaque job IDs into new automation.
- Normalized event: use `scripts/emit-event.sh`; it writes JSON under
  `~/.local/state/hermes-ops/events/` and prints the exact path.

## Non-negotiable workstation facts

- Persistent package and service changes belong in `/home/cjm/dotfiles`.
- Validate system changes with `nh os build /home/cjm/dotfiles`. Carter applies
  the privileged switch with `nrs`; agent shells cannot provide sudo.
- Fish aliases/functions are unavailable in non-interactive commands. Use full
  commands or a declarative wrapper.
- Prefer `rg`, `rg --files`, and explicitly bounded scans. Never breadth-scan
  `/home/cjm`.
- Treat `/home/cjm/projects` as canonical when duplicates exist, but verify Git
  remote and recent activity before choosing.
- Do not print environment files, tokens, credential stores, or unbounded
  journals. Put detailed diagnostics in a mode-0600 local event attachment.
- Terminal access is intentional: Hermes uses the local persistent backend and
  receives the full Home Manager/NixOS PATH through its gateway drop-in.

## Verification standard

Report the command and the observed state: build result, unit state, timer next
run, endpoint response, container health, Git status, or event file. If live
state changed, re-read it after the change. If a condition caused a unit to skip,
inspect `ConditionResult`; a successful unit result can still mean no work ran.
