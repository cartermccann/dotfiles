{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  waylandFlags = [
    "--ozone-platform-hint=auto"
    "--enable-features=TouchpadOverscrollHistoryNavigation,WebRTCPipeWireCapturer"
  ];

  google-chrome-wrapped = pkgs.google-chrome.override {
    commandLineArgs = waylandFlags ++ [
      "--disable-accelerated-video-decode"
      "--disable-gpu-video-decoder"
      "--oauth2-client-id=77185425430.apps.googleusercontent.com"
      "--oauth2-client-secret=OTJgUOQcT7lO7GsGZq2G4IlT"
    ];
  };

  chromium-wrapped = pkgs.chromium.override {
    commandLineArgs = waylandFlags;
  };
in
{
  programs.chromium.enable = true;
  environment.systemPackages = with pkgs; [
    google-chrome-wrapped
    chromium-wrapped

    # Communication
    slack
    pkgs-unstable.beeper
    # Utilities
    localsend # local file sharing
    nautilus # file manager
    gnome-disk-utility
    gnome-calculator
    fastfetch
    inxi
  ];
}
