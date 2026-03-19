{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop-niri.nix
    ../../modules/nvidia.nix
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

  networking.hostName = "kronos";

  # Ollama — high tier: RTX 5070 (12GB VRAM) + 64GB RAM
  # Runs via Docker with GPU passthrough (see modules/ollama.nix)
  local.ollamaTier = "high";

  system.stateVersion = "25.11";
}
