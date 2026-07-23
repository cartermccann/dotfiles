{
  config,
  lib,
  pkgs,
  user,
  hermes-agent,
  ...
}:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./niri.nix
    ./niri-noctalia.nix
    ./hyprland.nix
    ./qs-shell.nix
    ./tmux.nix
    ./dictation.nix
    ./tools.nix
    ./hermes.nix
    ./hermes-meet.nix
    ./headroom.nix
    ./vault-brain-sync.nix
    ./self-improve-loop.nix
    ./codex-self-improve-loop.nix
    ./pr-babysit-loop.nix
    ./ci-triage-loop.nix
    ./docs-gardener-loop.nix
    ./knockturnal-warmer.nix
    ./hermes-events.nix
    ./ghostty.nix
    ./swaylock.nix
    ./spotify.nix
  ];

  home.username = user;
  home.homeDirectory = "/home/${user}";

  # XDG user directories — keep the ones we use, redirect the rest
  xdg.userDirs = {
    enable = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    music = "$HOME/.local/share/Music";
    publicShare = "$HOME/.local/share/Public";
    templates = "$HOME/.local/share/Templates";
  };

  gtk.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.file."wallpapers".source = ../wallpaper;

  # Figma (Chrome web app)
  xdg.desktopEntries.figma = {
    name = "Figma";
    comment = "Figma Design";
    exec = "google-chrome-stable --app=https://figma.com/ %U";
    terminal = false;
    icon = ./icons/Figma.png;
    categories = [
      "Graphics"
      "Development"
    ];
  };

  # Buzz (Block's agent workspace) — AppImage in ~/Applications, runs via
  # programs.appimage binfmt; wrapper auto-starts the local relay stack from
  # ~/projects/buzz if ws://localhost:3000 is down
  xdg.desktopEntries.buzz = {
    name = "Buzz";
    genericName = "Agent Workspace";
    comment = "Block's human + AI agent workspace (local relay)";
    exec = toString (
      pkgs.writeShellScript "buzz-launch" ''
        repo="$HOME/projects/buzz"
        if ! ${pkgs.curl}/bin/curl -sf -o /dev/null --max-time 2 http://127.0.0.1:3000; then
          if [ -x "$repo/target/debug/buzz-relay" ]; then
            (
              cd "$repo"
              /run/current-system/sw/bin/docker compose up -d >/dev/null 2>&1
              set -a
              . ./.env 2>/dev/null
              set +a
              # serve the built web UI alongside the relay (http://localhost:3000)
              export BUZZ_WEB_DIR=./web/dist BUZZ_SERVE_GIT_WEB_GUI=true
              setsid ./target/debug/buzz-relay >> "$HOME/.cache/buzz-relay.log" 2>&1 < /dev/null &
            )
            for _ in $(seq 1 30); do
              ${pkgs.curl}/bin/curl -sf -o /dev/null --max-time 1 http://127.0.0.1:3000 && break
              sleep 1
            done
          fi
        fi
        # GTK3/WebKit hits "Error 71 (Protocol error)" on this Wayland session
        # and dies; XWayland is stable (the upstream AppImage also ran under it).
        export GDK_BACKEND=x11
        # WebKit's DMABUF renderer cannot allocate GBM buffers here ("Failed to
        # create GBM buffer ... Invalid argument") and paints an empty window.
        export WEBKIT_DISABLE_DMABUF_RENDERER=1
        export WEBKIT_DISABLE_COMPOSITING_MODE=1
        # The binary is built outside a derivation, so wrapGAppsHook never wraps
        # it and GTK finds no GSettings schemas. Opening a file dialog then hits
        # a fatal GLib-GIO-ERROR (schema 'org.gtk.Settings.FileChooser') and
        # aborts the process. Point it at the schemas explicitly.
        export GSETTINGS_SCHEMA_DIR="${
          lib.concatMapStringsSep ":" (p: "${p}/share/gsettings-schemas/${p.name}/glib-2.0/schemas") [
            pkgs.gtk3
            pkgs.gsettings-desktop-schemas
          ]
        }"
        # System GStreamer for media/notification sounds; bad+libav supply the
        # AAC decoder the app asks for on boot.
        export GST_PLUGIN_SYSTEM_PATH_1_0="${
          lib.makeSearchPath "lib/gstreamer-1.0" (
            with pkgs.gst_all_1;
            [
              gstreamer
              gst-plugins-base
              gst-plugins-good
              gst-plugins-bad
              gst-libav
            ]
          )
        }"
        export BUZZ_RELAY_URL="''${BUZZ_RELAY_URL:-ws://localhost:3000}"
        # Agent mentions spawn the ACP harness (buzz-acp) plus the other
        # workspace binaries; the app resolves them beside itself or on PATH.
        # Built by: cargo build --release --workspace
        export PATH="$repo/target/release:$PATH"
        exec "$repo/desktop/src-tauri/target/release/buzz-desktop" "$@"
      ''
    );
    terminal = false;
    icon = ./icons/Buzz.png;
    categories = [
      "Development"
      "Network"
    ];
  };

  # Hermes Desktop (flake package ships the binary, but currently not a .desktop file)
  xdg.desktopEntries.hermes-desktop = {
    name = "Hermes";
    genericName = "AI Agent Desktop";
    comment = "Hermes Agent desktop app";
    exec = "hermes-desktop %U";
    terminal = false;
    icon = "${
      hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop
    }/share/hermes-desktop/dist/hermes.png";
    categories = [
      "Development"
      "Utility"
    ];
  };

  # Custom TUI launchers
  xdg.desktopEntries.disk-usage = {
    name = "Disk Usage";
    comment = "View disk usage with dust";
    exec = toString (
      pkgs.writeShellScript "disk-usage-tui" ''
        ghostty --class=TUI.float -e bash -c 'dust -r; read -n 1 -s'
      ''
    );
    terminal = false;
    icon = "disk-usage-analyzer";
    categories = [ "System" ];
  };

  xdg.desktopEntries.docker = {
    name = "Docker";
    comment = "Docker";
    exec = "ghostty --class=TUI.tile -e lazydocker";
    terminal = false;
    icon = "docker-desktop";
    categories = [ "System" ];
  };

  home.stateVersion = "25.11";
}
