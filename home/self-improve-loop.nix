{
  config,
  lib,
  pkgs,
  ...
}:

# Self-improvement loop — mines recent Claude Code transcripts for durable
# feedback (corrections, repeated asks, anti-patterns) under a strict
# anti-slop constitution, then stops.
#
# The behavior lives in the skill (~/.claude/skills/loop-self-improve/); this
# module only provides the schedule. One headless `claude -p` run every two
# days. Auto-writes are limited to memory files; anything touching CLAUDE.md,
# skills, or hooks lands as a human-gated proposal in
# ~/.claude/self-improve/PROPOSALS.md.
#
# Headless runs can't answer permission prompts, so the sweep runs against a
# scoped allowlist (sweep-settings.json in the skill dir): the extractor
# script + read-only text tools, reads under ~/.claude, writes ONLY to
# ~/.claude/self-improve and the memory dir, subagents allowed; web access
# and edits to CLAUDE.md/skills/settings are explicitly denied. Everything
# else auto-denies. CLAUDE.md/skill changes therefore can only ever land as
# human-gated proposals — the loop is structurally unable to apply them.
let
  homeDir = config.home.homeDirectory;
  claude = "${homeDir}/.local/bin/claude";
  sweepSettings = "${homeDir}/.claude/skills/loop-self-improve/sweep-settings.json";
in
{
  systemd.user.services.self-improve-loop = {
    Unit = {
      Description = "Claude self-improvement sweep (transcript mining, anti-slop)";
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
        # per-user profile provides node (plugin SessionEnd hooks need it).
        "PATH=${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      WorkingDirectory = homeDir;
      ExecStart = ''
        ${claude} -p "Invoke the loop-self-improve skill and run ONE sweep, then stop." --settings ${sweepSettings}
      '';
    };
  };

  systemd.user.timers.self-improve-loop = {
    Unit.Description = "Run the Claude self-improvement sweep every 2 days";
    Timer = {
      OnCalendar = "*-*-1/2 07:07:00";
      # Catch up after downtime instead of silently skipping a window.
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
