{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./niri.nix
    ./niri-noctalia.nix
    ./tmux.nix
    ./dictation.nix
    ./tools.nix
    ./spotify.nix
  ];

  home.username = user;
  home.homeDirectory = "/home/${user}";

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
