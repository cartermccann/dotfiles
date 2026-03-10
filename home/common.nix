{ config, pkgs, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./alacritty.nix
    ./niri.nix
    ./tmux.nix
  ];

  home.username = "carter";
  home.homeDirectory = "/home/carter";

  home.packages = with pkgs; [
    fastfetch
  ];

  # Wallpaper
  home.file."wallpaper.png".source = ../wallpaper/nord-landscape.png;

  home.stateVersion = "25.11";
}
