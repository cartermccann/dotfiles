{
  config,
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
    ./hyprland
    ./tmux.nix
    ./dictation.nix
    ./whisperlivekit.nix
    ./tools.nix
    ./hermes.nix
    ./webctx-tunnel.nix
    ./self-improve-loop.nix
    ./codex-self-improve-loop.nix
    ./codex-desktop.nix
    ./pr-babysit-loop.nix
    ./ci-triage-loop.nix
    ./docs-gardener-loop.nix
    ./hermes-events.nix
    ./ghostty.nix
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
