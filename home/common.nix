{ config, pkgs, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./alacritty.nix
  ];

  home.username = "carter";
  home.homeDirectory = "/home/carter";

  home.packages = with pkgs; [
    fastfetch
  ];

  # Qtile config
  xdg.configFile."qtile/config.py".source = ./qtile/config.py;
  xdg.configFile."qtile/autostart.sh" = {
    source = ./qtile/autostart.sh;
    executable = true;
  };
  xdg.configFile."qtile/show-keys.sh" = {
    source = ./qtile/show-keys.sh;
    executable = true;
  };

  # Wallpaper
  home.file."wallpaper.png".source = ../wallpaper/nord-landscape.png;

  # Rofi config
  xdg.configFile."rofi/config.rasi".source = ./rofi/config.rasi;

  home.stateVersion = "25.11";
}
