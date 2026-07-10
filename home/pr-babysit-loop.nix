{
  config,
  lib,
  pkgs,
  ...
}:

# Nightly PR-babysit loop — reviews open PRs across the comcreate-io GitHub org
# for correctness bugs, security issues, and missed edge cases, posts a single
# marker-gated comment per PR, then sends a Telegram digest and stops.
#
# The behavior lives in the skill (~/.claude/skills/loop-pr-babysit/); this
# module only provides the schedule + a failure alert. Comments post via the
# `gh` CLI as the `cartermccann` GitHub account (comment-only: never approve/
# merge/close). Headless runs can't answer permission prompts, so the sweep
# runs against a scoped allowlist (loop-settings.json in the skill dir): gh
# CLI, hermes send, reads/writes confined to the loop's own state dir;
# destructive gh subcommands, git, web access, and edits to CLAUDE.md/skills/
# settings are explicitly denied. Everything else auto-denies.
let
  homeDir = config.home.homeDirectory;
  claude = "${homeDir}/.local/bin/claude";
  loopSettings = "${homeDir}/.claude/skills/loop-pr-babysit/loop-settings.json";
  babysitPath = "PATH=${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin";
in
{
  systemd.user.services.pr-babysit-loop = {
    Unit = {
      Description = "Nightly PR babysit sweep (comcreate-io org, correctness/security review)";
      # Claude CLI must exist; skip cleanly otherwise.
      ConditionPathExists = claude;
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Alert Carter via Telegram instead of failing silently.
      OnFailure = [ "pr-babysit-loop-failed.service" ];
    };

    Service = {
      Type = "oneshot";
      # Generous but bounded: up to 6 fresh-subagent PR reviews need headroom
      # beyond the self-improve sweep's 45min budget.
      TimeoutStartSec = "60min";
      Environment = [
        # per-user profile provides node/gh/hermes/jq for the non-interactive
        # unit (load-bearing — a prior loop failed silently when fd/jq were
        # missing from this PATH).
        babysitPath
      ];
      WorkingDirectory = homeDir;
      ExecStart = ''
        ${claude} -p "Invoke the loop-pr-babysit skill and run ONE sweep, then stop." --settings ${loopSettings}
      '';
    };
  };

  systemd.user.services.pr-babysit-loop-failed = {
    Unit.Description = "Alert on pr-babysit-loop failure";
    Service = {
      Type = "oneshot";
      Environment = [
        babysitPath
      ];
      ExecStart = toString (
        pkgs.writeShellScript "pr-babysit-alert" ''
          ${homeDir}/.local/bin/hermes send -t telegram -s "pr-babysit FAILED" "Nightly PR review failed; see: journalctl --user -u pr-babysit-loop"
        ''
      );
    };
  };

  systemd.user.timers.pr-babysit-loop = {
    Unit.Description = "Run the nightly PR babysit sweep on weekday mornings";
    Timer = {
      OnCalendar = "Mon..Fri *-*-* 05:30:00";
      # Catch up after downtime instead of silently skipping a window.
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
