{
  config,
  lib,
  pkgs,
  user,
  ...
}:

# User-session coredump watcher, stolen from Omarchy's crash-watch (watch +
# mute + toast) without omarchy-agent-crash. systemd-coredump journals every
# core under MESSAGE_ID fc2e22bc6ee647b6b90729ab34a250b1; this unit follows
# that stream, drops OOM/SIGKILL / ignore-list / the watcher itself in code,
# then either asks Jev (Choice / Noul / Score, one request) or a deterministic
# fallback what to do: banner, silent-queue, or drop, plus a sticky per-program
# mute. Never execs an agent and never hands a core to Claude.
#
# Jev is used only when TYPESAFE_API_KEY is present (optional EnvironmentFile
# ~/.config/typesafe/env). There is no TypeSafe key in this flake yet; the
# fallback still toasts and mutes.
#
# Mutes live at ~/.local/state/crash-watch/ignore/<basename>, same sticky
# shape as WirePlumber's default.configured.audio.sink. Global off is
# ~/.local/state/crash-watch/off (also a systemd ConditionPathExists). CLI:
# `crash-mute`, `crash-mute <name> [on|off|toggle]`, `crash-mute --capture off`.
let
  homeDir = config.home.homeDirectory;

  crashWatch = pkgs.writeShellApplication {
    name = "crash-watch";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
      pkgs.coreutils
      pkgs.pipewire
      pkgs.swaynotificationcenter
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/crash-watch.py} "$@"
    '';
  };

  crashMute = pkgs.writeShellApplication {
    name = "crash-mute";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./scripts/crash-watch.py} mute "$@"
    '';
  };
in
{
  home.packages = [
    crashWatch
    crashMute
  ];

  systemd.user.services.crash-watch = {
    Unit = {
      Description = "Announce user-session coredumps (no agent)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # Not ConditionEnvironment=WAYLAND_DISPLAY: this flake imports that
      # variable in compositor/niri exec *after* graphical-session.target, so
      # Omarchy's UWSM-style check would leave the unit sitting failed. The
      # first toast waits for org.freedesktop.Notifications instead.
      # Omarchy's crash-capture-off: a disabled watcher stays disabled across
      # logins without masking the unit.
      ConditionPathExists = "!%h/.local/state/crash-watch/off";
    };

    Service = {
      Type = "simple";
      WorkingDirectory = homeDir;
      # Optional; the leading '-' means a missing file is not an error.
      EnvironmentFile = [ "-%h/.config/typesafe/env" ];
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.python3
            pkgs.systemd
            pkgs.coreutils
            pkgs.pipewire
            pkgs.swaynotificationcenter
          ]
        }:/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      ExecStart = "${crashWatch}/bin/crash-watch";
      Restart = "always";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
