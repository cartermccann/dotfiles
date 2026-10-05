{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  # The module (not the bare package) installs the setcap gsr-kms-server
  # wrapper that monitor capture needs on Wayland; hypr-record relies on it.
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    # Media players
    mpv
    # stable's 5.x builds hit TIDAL's S6007 playback error (stale Widevine);
    # unstable tracks upstream closely enough to keep DRM working
    pkgs-unstable.tidal-hifi

    # Video production
    obs-studio
    kdePackages.kdenlive
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
