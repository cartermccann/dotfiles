{ config, lib, pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = with pkgs; [ gutenprint ];
  };

  # mDNS for network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    system-config-printer
  ];
}
