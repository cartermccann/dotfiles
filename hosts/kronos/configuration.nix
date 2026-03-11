{ config, lib, pkgs, ... }:

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
    ../../modules/snapper.nix
    ../../modules/dictation.nix
    ../../modules/dev.nix
    ../../modules/media.nix
    ../../modules/apps.nix
  ];

  networking.hostName = "kronos";

  # LUKS encryption
  boot.initrd.luks.devices."root" = {
    device = "/dev/nvme0n1p2";
  };

  # AMD iGPU (for hardware decoding fallback)
  hardware.amd.amdgpu.amdvlk.enable = true;

  # Ollama — high tier: RTX 5070 (12GB VRAM) + 64GB RAM
  local.ollamaTier = "high";

  system.stateVersion = "25.11";
}
