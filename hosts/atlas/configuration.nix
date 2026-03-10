{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop-niri.nix
    ../../modules/ollama.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/printing.nix
    ../../modules/networking.nix
    ../../modules/dictation.nix
    ../../modules/dev.nix
    ../../modules/media.nix
    ../../modules/apps.nix
  ];

  networking.hostName = "atlas";

  # Broadcom BCM4331 WiFi
  hardware.firmware = [ pkgs.linux-firmware ];
  boot.kernelModules = [ "wl" ];
  boot.blacklistedKernelModules = [ "b43" "bcma" ];

  # Swap — gives headroom for LLMs
  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4GB
  }];

  # Ollama — CPU-only, i7 + 32GB RAM
  services.ollama = {
    enable = true;
    acceleration = false;
  };
  local.ollamaTier = "medium";

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
