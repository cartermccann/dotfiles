{ config, pkgs, user, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./alacritty.nix
    ./niri.nix
    ./tmux.nix
    ./dictation.nix
    ./openclaw.nix
  ];

  home.username = user;
  home.homeDirectory = "/home/${user}";

  home.packages = with pkgs; [
    fastfetch
  ];

  # Wallpaper
  home.file."wallpaper.png".source = ../wallpaper/nord-landscape.png;

  home.stateVersion = "25.11";
}
