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
