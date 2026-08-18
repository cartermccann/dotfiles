{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Media players
    mpv
    # stable's 5.x builds hit TIDAL's S6007 playback error (stale Widevine);
    # unstable tracks upstream closely enough to keep DRM working
    pkgs-unstable.tidal-hifi

    # Video production
    obs-studio
    kdePackages.kdenlive
    gpu-screen-recorder
    davinci-resolve

    # Image tools
    imagemagick
    imv # Wayland image viewer
    pinta # simple image editor
    satty # screenshot annotation

    # Documents
    libreoffice
    evince # PDF viewer
  ];
}
