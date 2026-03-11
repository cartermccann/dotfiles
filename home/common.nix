{ config, pkgs, user, matugen, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./ghostty.nix
    ./niri.nix
    ./tmux.nix
    ./dictation.nix
    ./openclaw.nix
    ./tools.nix
    ./theme.nix
  ];

  home.username = user;
  home.homeDirectory = "/home/${user}";

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  home.packages = with pkgs; [
    fastfetch
    papirus-icon-theme
  ];

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Wallpapers directory
  home.file."wallpapers".source = ../wallpaper;
  home.file."wallpaper.png".source = ../wallpaper/nord-landscape.png;

  # Figma (Chrome web app)
  xdg.desktopEntries.figma = {
    name = "Figma";
    comment = "Figma Design";
    exec = "google-chrome-stable --app=https://figma.com/ %U";
    terminal = false;
    icon = ./icons/Figma.png;
    categories = [ "Graphics" "Development" ];
  };

  # Custom TUI launchers
  xdg.desktopEntries.disk-usage = {
    name = "Disk Usage";
    comment = "View disk usage with dust";
    exec = toString (pkgs.writeShellScript "disk-usage-tui" ''
      ghostty --class=TUI.float -e bash -c 'dust -r; read -n 1 -s'
    '');
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
