{
  config,
  lib,
  pkgs,
  ...
}:

# Cursor self-hosted worker with computer use + desktop sharing.
#
# Cursor's docs give an Ubuntu apt line for this. The package names are
# Debian-isms; what the worker actually probes for is a list of *binaries*
# (`cursor-agent worker debug` prints it). This module supplies those binaries
# and runs the worker as a user service.
#
# Display strategy: the worker resolves a display in three steps — an explicit
# `--display`, then an inherited reachable `DISPLAY`, then a self-managed
# TigerVNC + Xfce desktop. We deliberately take the third path. This machine is
# a Wayland session (Hyprland/niri) whose `:0` is *rootless* Xwayland: it has no
# root window content, so `ffmpeg x11grab` against it captures nothing and
# xdotool cannot see Wayland-native windows. The agent instead gets its own
# sandboxed X11 desktop, which is also the safer arrangement — it never touches
# the real session.
#
# That is why UnsetEnvironment below matters: the graphical session pushes
# DISPLAY into the systemd user manager, and if the worker inherits it, it takes
# the broken second path instead of the managed one.

let
  homeDir = config.home.homeDirectory;

  # The self-updating Cursor install, NOT the nixpkgs `cursor-cli` in
  # home/tools.nix. As of 2026-09-18 the nixpkgs build (2026.07.23; unstable is
  # at 2026-08-31) has no `--computer-use` / `--share-desktop` flags at all —
  # verified with `worker --help` against both binaries. Only the upstream
  # channel (2026.09.15 here) carries the feature. Revisit and move this back
  # onto `pkgs.cursor-cli` once nixpkgs catches up; until then this is the one
  # imperative dependency in the setup and it is load-bearing.
  cursorAgent = "${homeDir}/.local/bin/cursor-agent";

  # nixpkgs builds TigerVNC's upstream install target, which names the server
  # `Xvnc`. Debian ships the same binary as `Xtigervnc`, and that is the name
  # Cursor's preflight looks for. Bridge the two rather than patching tigervnc.
  tigervncCompat = pkgs.runCommand "tigervnc-xtigervnc-compat" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.tigervnc}/bin/Xvnc $out/bin/Xtigervnc
  '';

  # Enough of Xfce to bring up a session with a window manager. Deliberately
  # minimal: no Thunar, no goodies. The agent needs a managed desktop, not a
  # daily driver.
  xfcePackages = with pkgs.xfce; [
    xfce4-session
    xfwm4
    xfce4-panel
    xfdesktop
    xfce4-settings
  ];

  workerPackages =
    (with pkgs; [
      xdotool # synthesises clicks and keystrokes
      ffmpeg # screen capture
      dbus # dbus-launch, the `dbus-x11` half of the apt line
      tigervnc # Xvnc, vncconfig, vncpasswd
      tigervncCompat # + the Xtigervnc alias Cursor probes for
    ])
    ++ (with pkgs.xorg; [
      xdpyinfo # x11-utils
      xprop # x11-utils
      xrandr # x11-xserver-utils
      xsetroot # x11-xserver-utils
      xauth # Xvnc needs it for the MIT-MAGIC-COOKIE
    ])
    ++ xfcePackages;

  # System path last, so the worker finds the Chrome wrapper from
  # modules/apps.nix without pulling a second full Chrome closure in here.
  # Its `--ozone-platform-hint=auto` resolves to X11 inside Xvnc, so the
  # Wayland-oriented flags are harmless on the agent desktop.
  workerPath = "${lib.makeBinPath workerPackages}:/run/current-system/sw/bin";

  # xfce4-session reads autostart and session .desktop files out of
  # XDG_DATA_DIRS. Without this it comes up as an empty root window with no
  # panel and no window manager.
  workerDataDirs = "${lib.makeSearchPath "share" workerPackages}:/run/current-system/sw/share";

  # `cursor-agent worker debug` run from an ordinary shell reports everything
  # missing, because these packages are intentionally kept off the interactive
  # PATH. This runs the same preflight with the service's environment, which is
  # the environment that actually matters.
  preflight = pkgs.writeShellScriptBin "cursor-worker-preflight" ''
    export PATH="${workerPath}:$PATH"
    export XDG_DATA_DIRS="${workerDataDirs}"
    unset DISPLAY WAYLAND_DISPLAY
    exec ${cursorAgent} worker debug "$@"
  '';
in
{
  home.packages = [ preflight ];

  systemd.user.services.cursor-worker = {
    Unit = {
      Description = "Cursor self-hosted worker (computer use + desktop sharing)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = cursorAgent;
    };

    Service = {
      Type = "simple";

      # Worker flags go before `start`; `--share-desktop` with no argument means
      # view_and_control. Narrow it to watch-only with `--share-desktop view`.
      # No `--display` on purpose — see the header comment.
      ExecStart = lib.concatStringsSep " " [
        cursorAgent
        "worker"
        "--computer-use"
        "--share-desktop"
        "--name kronos"
        "start"
      ];

      Environment = [
        "PATH=${workerPath}"
        "XDG_DATA_DIRS=${workerDataDirs}"
      ];

      # The graphical session imports DISPLAY/WAYLAND_DISPLAY into the user
      # manager. Drop both so the worker cannot latch onto rootless Xwayland and
      # must build its own desktop.
      UnsetEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
      ];

      Restart = "always";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
