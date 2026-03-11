{ config, pkgs, user, ... }:

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
  ];

  # Wallpaper
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

  home.stateVersion = "25.11";
}
