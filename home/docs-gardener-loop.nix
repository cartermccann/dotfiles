{
  config,
  lib,
  pkgs,
  ...
}:

# Docs-drift gardener — weekly audit of project CLAUDE.md files against
# actual repo state (stale commands, dead paths/imports, rules that fail the
# deletion test), then files findings as human-gated proposals into the
# EXISTING shared gate at ~/.claude/self-improve/PROPOSALS.md.
#
# The behavior lives in the skill (~/.claude/skills/loop-docs-gardener/);
# this module only provides the schedule. One headless `claude -p` run every
# week. This loop never edits any CLAUDE.md/AGENTS.md/skill/rules file
# itself — everything lands as a human-gated proposal, same two-tier sink as
# loop-self-improve, with the "auto" tier empty here.
#
# Headless runs can't answer permission prompts, so the sweep runs against a
# scoped allowlist (loop-settings.json in the skill dir): the repo-state.sh
# helper + read-only text tools, read-only access under ~/projects,
# ~/CLAUDE.md, ~/dotfiles, and ~/.claude, writes ONLY to
# ~/.claude/self-improve/** and ~/.claude/loops/docs-gardener/**; web access
# and edits to CLAUDE.md/skills/settings/rules are explicitly denied.
# Everything else auto-denies.
#
# Scheduled Sunday ~09:30 — deliberately offset from self-improve-loop's
# every-2-days 07:07 slot to avoid concurrent PROPOSALS.md appends.
# After = self-improve-loop.service additionally orders the two if a
# Persistent catch-up after downtime enqueues both at once.
let
  homeDir = config.home.homeDirectory;
  claude = "${homeDir}/.local/bin/claude";
  gardenerSettings = "${homeDir}/.claude/skills/loop-docs-gardener/loop-settings.json";
in
{
  systemd.user.services.docs-gardener-loop = {
    Unit = {
      Description = "Claude docs-drift gardener (project CLAUDE.md audit, proposals only)";
      # Claude CLI must exist; skip cleanly otherwise.
      ConditionPathExists = claude;
      After = [
        "network-online.target"
        "self-improve-loop.service"
      ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      # Audit is lighter than transcript mining; bounded well under this.
      TimeoutStartSec = "30min";
      Environment = [
        # per-user profile provides fd/jq/git (fd/jq missing from the
        # non-interactive PATH was a real prior silent failure).
        "PATH=${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      WorkingDirectory = homeDir;
      ExecStart = ''
        ${claude} -p "Invoke the loop-docs-gardener skill and run ONE audit sweep, then stop." --settings ${gardenerSettings}
      '';
    };
  };

  systemd.user.timers.docs-gardener-loop = {
    Unit.Description = "Run the Claude docs-drift gardener weekly";
    Timer = {
      OnCalendar = "Sun *-*-* 09:30:00";
      # Catch up after downtime instead of silently skipping a window.
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
