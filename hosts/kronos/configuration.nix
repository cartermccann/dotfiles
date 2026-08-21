{
  config,
  lib,
  pkgs,
  korgo,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    korgo.nixosModules.korgo-ssh-client
    ../../modules/common.nix
    ../../modules/desktop-wayland.nix
    ../../modules/desktop-niri-noctalia.nix
    ../../modules/desktop-hyprland.nix
    ../../modules/nvidia.nix
    ../../modules/ollama.nix
    ../../modules/llama-heavy.nix
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/printing.nix
    ../../modules/networking.nix
    ../../modules/dictation.nix
    ../../modules/dev.nix
    ../../modules/media.nix
    ../../modules/apps.nix
    ../../modules/oom-protection.nix
  ];

  users.users.cjm.uid = 1000;

  systemd.tmpfiles.rules = [
    "d /var/lib/korgo-ssh-secrets 0700 cjm users - -"
  ];

  services.korgo-ssh-client = {
    enable = true;
    package = korgo.packages.x86_64-linux.korgo-linux-mini-client;
    user = "cjm";
    group = "users";
    uid = 1000;
    miniAddress = "100.92.118.102";
    port = 22;
    identityFile = "/var/lib/korgo-ssh-secrets/identity";
    knownHostsFile = "/var/lib/korgo-ssh-secrets/known_hosts";
    knownHostsSha256 = "22027cbf6896e265d62ebf67f61914269698368b973ba191032192261f1e152d";
    hostKeyFingerprint = "SHA256:QqLF3mcRl70gKZY//Kxlrb814fmUGXA8sAZN/UOcIEc";
    waylandDisplay = "wayland-1";
  };

  networking.hostName = "kronos";

  # Larger console font for Ly login manager on high-res display
  console = {
    font = "ter-v24n";
    packages = [ pkgs.terminus_font ];
    earlySetup = true;
  };

  # Ollama — high tier: RTX 5070 (12GB VRAM) + 64GB RAM (see modules/ollama.nix)
  local.ollamaTier = "high";

  system.stateVersion = "25.11";
}
