{ config, lib, pkgs, ... }:

# Host-specific Ollama model management
# Set `local.ollamaTier` in each host's configuration.nix:
#   local.ollamaTier = "high";   # desktop — RTX 5070 12GB + 64GB RAM
#   local.ollamaTier = "medium"; # atlas   — i7 CPU + 32GB RAM
#   local.ollamaTier = "low";    # minimal — 16GB RAM or less

let
  # Model presets by hardware tier
  modelsByTier = {
    high = [
      "qwen3.5:4b"         # fast simple tasks, fully in VRAM
      "qwen3.5:9b"         # strong coding/general, fully in 12GB VRAM
      "deepseek-r1:14b"    # reasoning, fits in 12GB VRAM
    ];
    medium = [
      "qwen3.5:4b"         # fast, runs well on CPU w/ 32GB
      "llama3.2:3b"        # lightweight fallback
    ];
    low = [
      "llama3.2:3b"        # only small models
    ];
  };

  tier = config.local.ollamaTier;
  models = modelsByTier.${tier};

  # Script to pull models if not already present
  preloadScript = pkgs.writeShellScript "ollama-preload-models" ''
    set -euo pipefail
    echo "Ollama model preload — tier: ${tier}"
    echo "Waiting for Ollama to be ready..."

    for i in $(seq 1 30); do
      if ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if ! ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
      echo "Ollama not reachable, skipping model preload"
      exit 0
    fi

    INSTALLED=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags | ${pkgs.jq}/bin/jq -r '.models[].name' 2>/dev/null || echo "")

    ${lib.concatMapStringsSep "\n" (model: ''
      if echo "$INSTALLED" | grep -q "^${model}$"; then
        echo "Already have: ${model}"
      else
        echo "Pulling: ${model}..."
        ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/pull -d '{"name": "${model}"}' > /dev/null
        echo "Done: ${model}"
      fi
    '') models}

    echo "Model preload complete."
  '';
in
{
  options.local.ollamaTier = lib.mkOption {
    type = lib.types.enum [ "low" "medium" "high" ];
    default = "medium";
    description = "Hardware tier for Ollama model selection";
  };

  config = {
    # Oneshot service to pull models after Ollama starts
    systemd.services.ollama-preload = {
      description = "Preload Ollama models for this machine's tier";
      after = [ "ollama.service" "network-online.target" ];
      wants = [ "ollama.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = preloadScript;
        RemainAfterExit = true;
      };
    };
  };
}
