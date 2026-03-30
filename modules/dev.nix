{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    docker-compose

    # Build essentials (needed by Python native extensions, Rust C bindings, Node native modules)
    gcc
    gnumake
    pkg-config
    openssl
    openssl.dev
  ];

  virtualisation.docker.enable = true;
}
