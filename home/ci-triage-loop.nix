{
  config,
  lib,
  pkgs,
  ...
}:

# CI-failure triage loop — polls failed GitHub Actions runs across the
# comcreate-io org, diagnoses root cause, posts ONE diagnosis comment per
# failure, and — only for clear-cut mechanical failures that pass a local
# reproduce-before/pass-after oracle — pushes a `ci-fix/*` branch and opens a
# DRAFT PR. Same infra pattern as self-improve-loop.nix.
#
# The behavior lives in the skill (~/.claude/skills/loop-ci-triage/); this
# module only provides the schedule. Headless `claude -p` runs every 4 hours,
# 06:00-22:00.
#
# Headless runs can't answer permission prompts, so the sweep runs against a
# scoped allowlist (loop-settings.json in the skill dir): gh reads + comment/
# draft-PR writes, git clone scoped to comcreate-io URLs, non-push git ops
# scoped to the loop's work dir, hermes send, reads/writes confined to the
# loop's state dir. ALL raw `git push` forms are deny-listed; the only push
# path is scripts/push-ci-fix.sh, which enforces comcreate-io-origin-only,
# ci-fix/*-branch-only, no existing remote branch, no force. Merge and
# ready-for-review are unreachable both as gh CLI commands (gh pr merge/
# ready/close/review/edit denied) and via the API (gh api graphql and
# -X/--method PUT/DELETE denied) — Carter reviews and merges ci-fix/* PRs
# manually. Everything else auto-denies.
let
  homeDir = config.home.homeDirectory;
  claude = "${homeDir}/.local/bin/claude";
  loopSettings = "${homeDir}/.claude/skills/loop-ci-triage/loop-settings.json";
in
{
  systemd.user.services.ci-triage-loop = {
    Unit = {
      Description = "Claude CI-failure triage sweep (comcreate-io)";
      # Claude CLI must exist; skip cleanly otherwise.
      ConditionPathExists = claude;
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      # Generous but bounded: a sweep should finish well inside this; if it
      # wedges, kill it rather than leak a stuck agent.
      TimeoutStartSec = "45min";
      Environment = [
        # per-user profile provides node/gh (non-interactive units lack the
        # home-manager profile).
        "PATH=${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      WorkingDirectory = homeDir;
      ExecStart = ''
        ${claude} -p "Invoke the loop-ci-triage skill and run ONE sweep, then stop." --settings ${loopSettings}
      '';
    };
  };

  systemd.user.timers.ci-triage-loop = {
    Unit.Description = "Run the Claude CI-triage sweep twice daily (starting cadence)";
    Timer = {
      # Starting cadence: 2x/day while trust builds against a noisy CI estate;
      # raise toward every-4h ("*-*-* 06,10,14,18,22:00:00") once sweeps prove quiet.
      OnCalendar = "*-*-* 08,15:00:00";
      # Catch up after downtime instead of silently skipping a window.
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
