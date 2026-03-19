{ config, lib, pkgs, ... }:

{
  # Tailscale VPN (works with Headscale too)
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both"; # exit node + subnet routing

  # Firewall
  networking.firewall = {
    enable = true;
    # Allow Tailscale
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    # LocalSend
    allowedTCPPorts = [ 53317 ];
    allowedUDPPortRanges = [{ from = 53317; to = 53317; }];
  };

  environment.systemPackages = with pkgs; [
    tailscale
  ];
}
