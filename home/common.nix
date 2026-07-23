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
        # appimage-run's FHS env exposes no NVIDIA GL driver, so WebKitGTK's
        # EGL/dri2 init fails and the web view paints nothing. llvmpipe renders
        # in software instead (verified: EGL errors 3 -> 0).
        export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
        export BUZZ_RELAY_URL="''${BUZZ_RELAY_URL:-ws://localhost:3000}"
        exec "$HOME/Applications/Buzz.AppImage" "$@"
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
