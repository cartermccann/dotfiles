{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  zen-browser,
  helium,
  ...
}:

let
  waylandFlags = [
    "--ozone-platform-hint=auto"
    "--enable-features=TouchpadOverscrollHistoryNavigation,WebRTCPipeWireCapturer"
  ];

  googleChromeWrapped = pkgs.google-chrome.override {
    commandLineArgs = waylandFlags ++ [
      "--disable-accelerated-video-decode"
      "--disable-gpu-video-decoder"
      "--oauth2-client-id=77185425430.apps.googleusercontent.com"
      "--oauth2-client-secret=OTJgUOQcT7lO7GsGZq2G4IlT"
    ];
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

  environment.systemPackages = with pkgs; [
    # Browsers
    googleChromeWrapped
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    floorp-bin
    helium.packages.${pkgs.stdenv.hostPlatform.system}.default

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
    blanket
    statix # nix linter

    # Notes
    obsidian
  ];
}
