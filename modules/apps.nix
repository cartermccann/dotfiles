{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  zen-browser,
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
  programs._1password = {
    enable = true;
    package = pkgs-unstable._1password-cli;
  };
  programs._1password-gui = {
    enable = true;
    package = pkgs-unstable._1password-gui;
    polkitPolicyOwners = [ "cjm" ];
  };

  programs.chromium.enable = true;
  environment.systemPackages = with pkgs; [
    google-chrome-wrapped
    chromium-wrapped

    # Design-focused browsers
    zen-browser.packages.${pkgs.system}.default
    floorp-bin
    vivaldi

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
