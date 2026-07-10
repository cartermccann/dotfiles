{
  config,
  ...
}:

# Proposal-only Codex self-improvement loop. The Codex process is read-only and
# ignores saved execpolicy approvals; the wrapper writes only inert evidence and
# proposal state under ~/.codex/self-improve.
let
  homeDir = config.home.homeDirectory;
  codex = "/etc/profiles/per-user/cjm/bin/codex";
  runner = "${homeDir}/.codex/skills/codex-self-improve/scripts/run-sweep.sh";
in
{
  systemd.user.services.codex-self-improve-loop = {
    Unit = {
      Description = "Codex self-improvement proposal sweep";
      ConditionPathExists = [
        codex
        runner
      ];
    };

    Service = {
      Type = "oneshot";
      TimeoutStartSec = "45min";
      Environment = [
        "PATH=${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      WorkingDirectory = homeDir;
      ExecStart = runner;
    };
  };

  systemd.user.timers.codex-self-improve-loop = {
    Unit.Description = "Run the Codex self-improvement proposal sweep every 2 days";
    Timer = {
      OnCalendar = "*-*-1/2 07:27:00";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
