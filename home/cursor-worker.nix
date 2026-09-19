{
  config,
  lib,
  pkgs,
  ...
}:

# Cursor self-hosted worker with computer use + desktop sharing.
#
# Cursor documents this as an Ubuntu apt line. On NixOS three of those packages
# are either named differently, built without the feature Cursor needs, or
# actively broken against a VNC X server. What the worker really probes for is a
# list of binaries, printed by `cursor-agent worker debug`.
#
# Display strategy: this machine runs a Wayland session whose :0 is *rootless*
# Xwayland, which has no root window content, so x11grab against it captures
# nothing and xdotool cannot see Wayland-native windows. We therefore give the
# agent its own Xvnc desktop on a pinned display and point the worker at it with
# --display. Pinning matters for more than tidiness: left to pick its own
# display the worker grabbed :0, and on teardown deleted Hyprland's
# /tmp/.X11-unix/X0 socket, taking X11 down for the whole live session.

let
  homeDir = config.home.homeDirectory;

  agentDisplay = ":20";
  agentGeometry = "1920x1080";

  # The self-updating Cursor install, NOT the nixpkgs `cursor-cli` in
  # home/tools.nix: that build (2026.07.23, unstable at 2026-08-31) has no
  # --computer-use or --share-desktop flags at all, verified against both
  # binaries. Move back to pkgs.cursor-cli once nixpkgs catches up.
  cursorAgent = "${homeDir}/.local/bin/cursor-agent";

  # nixpkgs names TigerVNC's server Xvnc; Debian ships the same binary as
  # Xtigervnc, which is the name Cursor's preflight looks for.
  tigervncCompat = pkgs.runCommand "tigervnc-xtigervnc-compat" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.tigervnc}/bin/Xvnc $out/bin/Xtigervnc
  '';

  # Cursor waits for a window manager to claim _NET_SUPPORTING_WM_CHECK on the
  # display, and gets there by running `startxfce4`. Do not use the real one.
  # xfce4-session drags in xfconf, a session manager and a panel, and the whole
  # stack dies within seconds on Xvnc: xfwm4's compositor needs
  # GLX_EXT_texture_from_pixmap, which Xvnc does not provide, so it aborts with
  # "No provider of glXBindTexImageEXT found" and takes the ICE session down
  # with it. xfwm4 with compositing off is stable, needs neither D-Bus nor
  # xfconf, and is all Cursor is actually waiting for.
  startxfce4Shim = pkgs.writeShellScriptBin "startxfce4" ''
    exec ${pkgs.xfce.xfwm4}/bin/xfwm4 --compositor=off
  '';

  # nixpkgs' default ffmpeg is built without xcb, so it has no x11grab muxer and
  # every screenshot fails. The preflight only checks that an `ffmpeg` binary
  # exists, so this failure is invisible until an agent tries to take a picture.
  # ffmpeg-full carries "x11grab  X11 screen capture, using XCB".
  ffmpegX11 = pkgs.ffmpeg-full;

  workerPackages = [
    startxfce4Shim # must precede anything else providing startxfce4
    ffmpegX11
    tigervncCompat
  ]
  ++ (with pkgs; [
    xdotool # synthesises clicks and keystrokes
    dbus # dbus-launch, the `dbus-x11` half of the apt line
    tigervnc # Xvnc
    xfce.xfwm4 # the window manager Cursor waits for
  ])
  ++ (with pkgs.xorg; [
    xdpyinfo # x11-utils, also used below to wait for the display
    xprop # x11-utils
    xrandr # x11-xserver-utils
    xsetroot # x11-xserver-utils
    xauth # MIT-MAGIC-COOKIE handling
  ]);

  # System path last so the worker finds the Chrome wrapper from
  # modules/apps.nix without pulling a second Chrome closure in here.
  workerPath = "${lib.makeBinPath workerPackages}:/run/current-system/sw/bin";
  workerDataDirs = "${lib.makeSearchPath "share" workerPackages}:/run/current-system/sw/share";

  # Owns the agent's X server and window manager. Kept in one unit so the WM
  # dying takes the display down with it and systemd rebuilds both together,
  # rather than leaving a headless Xvnc for the worker to attach to.
  agentDesktop = pkgs.writeShellScript "cursor-agent-desktop" ''
    set -eu
    export PATH="${workerPath}"
    export XDG_DATA_DIRS="${workerDataDirs}"
    unset DISPLAY WAYLAND_DISPLAY

    xvnc_pid=""
    cleanup() { [ -n "$xvnc_pid" ] && kill "$xvnc_pid" 2>/dev/null || true; }
    trap cleanup EXIT INT TERM

    Xvnc ${agentDisplay} -geometry ${agentGeometry} -depth 24 \
      -SecurityTypes None -localhost -NeverShared &
    xvnc_pid=$!

    for _ in $(seq 1 60); do
      xdpyinfo -display ${agentDisplay} >/dev/null 2>&1 && break
      sleep 0.25
    done
    if ! xdpyinfo -display ${agentDisplay} >/dev/null 2>&1; then
      echo "Xvnc never came up on ${agentDisplay}" >&2
      exit 1
    fi

    export DISPLAY=${agentDisplay}
    xfwm4 --compositor=off &
    wm_pid=$!
    wait "$wm_pid"
  '';

  # `cursor-agent worker debug` from an ordinary shell reports everything
  # missing, because these packages are deliberately kept off the interactive
  # PATH. This runs the same preflight with the service's environment.
  preflight = pkgs.writeShellScriptBin "cursor-worker-preflight" ''
    export PATH="${workerPath}"
    export XDG_DATA_DIRS="${workerDataDirs}"
    export DISPLAY=${agentDisplay}
    exec ${cursorAgent} worker --worker-dir ${homeDir}/projects debug "$@"
  '';
in
{
  home.packages = [ preflight ];

  systemd.user.services.cursor-agent-desktop = {
    Unit = {
      Description = "Xvnc + xfwm4 desktop for the Cursor agent (${agentDisplay})";
      PartOf = [ "cursor-worker.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${agentDesktop}";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.user.services.cursor-worker = {
    Unit = {
      Description = "Cursor self-hosted worker (computer use + desktop sharing)";
      After = [
        "network-online.target"
        "cursor-agent-desktop.service"
      ];
      Wants = [ "network-online.target" ];
      Requires = [ "cursor-agent-desktop.service" ];
      ConditionPathExists = cursorAgent;
    };

    Service = {
      Type = "simple";

      # Worker flags go before `start`. --share-desktop is watch-only: the
      # flag without a mode would mean view_and_control, which lets a viewer
      # take mouse and keyboard. --display pins the agent to the desktop above
      # so the worker never invents one. --worker-dir is the workspace root
      # exposed to agents; without it the worker defaults to its cwd, which
      # under systemd is $HOME and leaves the preflight warning about no git
      # origin for repo-based matching.
      ExecStart = lib.concatStringsSep " " [
        cursorAgent
        "worker"
        "--computer-use"
        "--share-desktop view"
        "--display ${agentDisplay}"
        "--worker-dir ${homeDir}/projects"
        "--name kronos"
        "start"
      ];

      Environment = [
        "PATH=${workerPath}"
        "XDG_DATA_DIRS=${workerDataDirs}"
        "DISPLAY=${agentDisplay}"
      ];

      Restart = "always";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
