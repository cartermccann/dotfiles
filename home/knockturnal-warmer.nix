{
  config,
  lib,
  pkgs,
  ...
}:

# Knockturnal cache-warmer — daily GSC hot-list push.
#
# The Knockturnal (client work, ~/projects/knockturnal-audit) runs a WordPress cache warmer
# (mu-plugin kt-warm.php on Pressable) that keeps the top pages hot. Its evergreen list of
# top GSC earners must be refreshed from Search Console, which only ComCreate's tooling can
# reach — so this timer runs the project's push script daily: it drives headless `claude` +
# the comcreate-marketing MCP to pull the top ~25 article pages and scp's them to the host.
#
# Runs through a fish LOGIN shell so the job inherits the full interactive PATH (the MCP's
# node lives at ~/.vite-plus/bin, claude at ~/.local/bin) — validated under systemd-run.
# Self-limiting: the script aborts without overwriting if the pull is short, and the warmer
# ignores a >36h-stale file (falls back to newest-20), so a missed run is harmless.
# Isolated module — remove this file + its import in common.nix to fully revert.
let
  homeDir = config.home.homeDirectory;
  script = "${homeDir}/projects/knockturnal-audit/scripts/kt-warmer-gsc-push.sh";
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
