{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Media players
    mpv
    spotify
    tidal-hifi

    # Video production
    obs-studio
    kdenlive
    gpu-screen-recorder

    # Image tools
    imagemagick
    imv     # Wayland image viewer
    pinta   # simple image editor
    satty   # screenshot annotation

    # Documents
    libreoffice
    evince  # PDF viewer
  ];
}
