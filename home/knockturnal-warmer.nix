{
  config,
  lib,
  pkgs,
  ...
}:

# Knockturnal cache-warmer — daily GSC hot-list push.
#
# The Knockturnal's WordPress cache warmer (mu-plugin kt-warm.php on Pressable,
# project at ~/projects/work/knockturnal-audit) keeps its top pages hot from a list of
# top GSC earners. Only ComCreate's tooling can reach Search Console, so this
# timer runs the project's push script daily: headless `claude` + the
# comcreate-marketing MCP pull the top ~25 article pages and scp them to the host.
#
# Runs through a fish login shell so the job inherits the full interactive PATH
# (the MCP's node lives at ~/.vite-plus/bin, claude at ~/.local/bin). A missed run
# is harmless: the script aborts rather than overwrite a short pull, and the
# warmer ignores a >36h-stale file. Remove this file + its import to revert.
let
  homeDir = config.home.homeDirectory;
  script = "${homeDir}/projects/work/knockturnal-audit/scripts/kt-warmer-gsc-push.sh";
in
{
  systemd.user.services.kt-warmer-gsc-push = {
    Unit = {
      Description = "Knockturnal cache-warmer — daily GSC hot-list push";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Skip cleanly if the project checkout is gone.
      ConditionPathExists = script;
    };

    Service = {
      Type = "oneshot";
      # Login shell -> full interactive env (PATH for node/claude/nix, MCP config under $HOME).
      ExecStart = ''${pkgs.fish}/bin/fish -l -c "bash ${script}"'';
      # Generous: the run drives a headless agent + MCP (~30s, but allow slack on a busy box).
      TimeoutStartSec = "10m";
    };
  };

  systemd.user.timers.kt-warmer-gsc-push = {
    Unit.Description = "Daily trigger for the Knockturnal GSC hot-list push";
    Timer = {
      OnCalendar = "*-*-* 09:30:00";
      Persistent = true; # catch up after a missed window (box asleep/off)
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
