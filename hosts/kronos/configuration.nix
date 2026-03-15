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

  # Ollama — high tier: RTX 5070 (12GB VRAM) + 64GB RAM
  # Runs via Docker with GPU passthrough (see modules/ollama.nix)
  local.ollamaTier = "high";

  # Pantheon AI stack
  # Bifrost is the only service with a working public Docker image right now.
  # RouteLLM, MetaMCP, NanoClaw, Mem0 don't have public images — enable when available.
  pantheon = {
    # Claude OAuth proxy — uses your Max subscription, not API keys
    claude-proxy.enable = true;

    bifrost = {
      enable = true;
      providers = {
        anthropic = {
          enable = true;
          baseUrl = "http://host.docker.internal:8317";  # CLIProxyAPI
        };
        openai.enable = true;
        ollama.enable = true;
      };
      secretsFile = "/home/cjm/.config/pantheon/secrets/bifrost.env";
    };
  };

  system.stateVersion = "25.11";
}
