{
  config,
  pkgs,
  ...
}:

# Reaps leaked MCP servers and headless Playwright browsers.
#
# Two leaks motivated this, both observed on kronos 2026-08-13:
#
#   * codex app-server never reaps MCP servers when a conversation ends. It had
#     accumulated 333 children / 20GB over ~27h, which exhausted 15GB of zram
#     and drove the load average to 18.
#
#   * playwright-mcp never reaps its headless browsers or their profile dirs.
#     53 abandoned profiles / 4.6GB had piled up, and one browser had wedged
#     rendering a WebGL page through SwiftShader (software rasterization, no
#     vsync ceiling), burning ~11 of 32 cores. Because the profile persisted
#     with session restore enabled, killing it just brought the same tab back.
#
# The script itself documents the confidence split between the two phases.
# Phase B ships DISARMED; flip armIdle once its dry-run logs look right.
let
  homeDir = config.home.homeDirectory;

  # Phase B kills processes, and the "is it live?" signal is inferred rather
  # than definitive. It judges whole fleets (codex spawns ~14 MCP servers per
  # conversation) and requires 80% of a fleet to have shown exactly zero bytes
  # read for 6h. Measured against 7 known-dead fleets on 2026-08-13 it scored
  # them 100% inert and correctly spared the two live ones.
  #
  # Residual risk: a conversation left OPEN but idle for 6h looks identical to
  # a closed one.
  #
  # ARMED 2026-09-01 on 6 days of dry-run evidence (Aug 25 22:54 -> Sep 1 09:19,
  # ~2500 runs). Of 18709 DEAD FLEET decisions, 18677 scored 100% inert and 32
  # scored 92% (one 12/13 fleet, re-flagged across consecutive runs). It never
  # named a fleet below the 80% threshold, and immediately after a manual sweep
  # it correctly reported 0 dead fleets against 121 live children -- i.e. it
  # does not over-flag. Trigger for arming was a leak to 811 children / 37.8GB,
  # which exhausted 60GB RAM and drove load to 33 with 48% iowait.
  armIdle = true;

  mcpReaper = pkgs.writeShellApplication {
    name = "mcp-reaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.procps
      pkgs.findutils
      pkgs.python3
    ];
    text = builtins.readFile ./scripts/mcp-reaper.sh;
  };
in
{
  home.packages = [ mcpReaper ];

  systemd.user.services.mcp-reaper = {
    Unit.Description = "Reap leaked MCP servers and headless Playwright browsers";

    Service = {
      Type = "oneshot";
      TimeoutStartSec = "5min";
      Environment = [
        "MCP_REAPER_ARM_IDLE=${if armIdle then "1" else "0"}"
        "PATH=/etc/profiles/per-user/cjm/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      WorkingDirectory = homeDir;
      ExecStart = "${mcpReaper}/bin/mcp-reaper";
    };
  };

  systemd.user.timers.mcp-reaper = {
    Unit.Description = "Run the MCP reaper every 10 minutes";
    Timer = {
      # This interval IS the worst-case burn time. A wedged SwiftShader browser
      # pins ~11 of 32 cores, and observed wedges happen ~90s after the browser
      # launches, so it is spinning for almost the whole gap between runs. At
      # 10min that was ~11 minutes of burn per occurrence (seen 17:55-18:08 on
      # 2026-08-13). A run costs ~4s, so 3min is cheap insurance.
      # Phase B's thresholds are in hours and are unaffected by this.
      OnBootSec = "2min";
      OnUnitActiveSec = "3min";
      Persistent = true;
      RandomizedDelaySec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
