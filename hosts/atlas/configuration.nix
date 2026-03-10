{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop-niri.nix
    ../../modules/dev.nix
  ];

  networking.hostName = "Atlas";

  # Broadcom BCM4331 WiFi
  hardware.firmware = [ pkgs.linux-firmware ];
  boot.kernelModules = [ "wl" ];
  boot.blacklistedKernelModules = [ "b43" "bcma" ];

  # Starlink WiFi auto-connect
  networking.networkmanager.ensureProfiles.profiles.starlink = {
    connection = {
      id = "STARLINK";
      type = "wifi";
      autoconnect = true;
    };
    wifi = {
      ssid = "STARLINK";
      mode = "infrastructure";
    };
    wifi-security = {
      key-mgmt = "wpa-psk";
      psk = "CHANGE_ME"; # Set your actual WiFi password before rebuilding
    };
  };

  system.stateVersion = "25.11";
}
