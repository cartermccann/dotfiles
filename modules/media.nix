{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Media players
    mpv
    tidal-hifi

    # Video production
    obs-studio
    kdePackages.kdenlive
    gpu-screen-recorder
    davinci-resolve

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
