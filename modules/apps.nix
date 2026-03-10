{ config, lib, pkgs, ... }:

{
  # Chrome
  programs.chromium.enable = true;
  environment.systemPackages = with pkgs; [
    google-chrome

    # Communication
    slack

    # Utilities
    localsend     # local file sharing
    nautilus      # file manager
    gnome-disk-utility
    gnome-calculator
    fastfetch
    inxi
  ];
}
