{ config, lib, pkgs, ... }:

# Ollama via Docker
# On GPU hosts: uses nvidia-container-toolkit for CUDA acceleration
# On CPU hosts: runs without GPU passthrough
# Avoids nixpkgs CUDA build issues (cicc crash on Blackwell/RTX 5070)

let
  modelsByTier = {
    high = [
      "qwen3.5:4b"
      "qwen3.5:9b"
      "deepseek-r1:14b"
    ];
    medium = [
      "qwen3.5:4b"
      "llama3.2:3b"
    ];
    low = [
      "llama3.2:3b"
    ];
  };

  tier = config.local.ollamaTier;
  models = modelsByTier.${tier};
  hasGpu = config.hardware.nvidia-container-toolkit.enable or false;

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
    virtualisation.oci-containers.containers.ollama = {
      image = "ollama/ollama";
      ports = [ "11434:11434" ];
      volumes = [ "ollama:/root/.ollama" ];
      extraOptions = lib.optionals hasGpu [ "--device=nvidia.com/gpu=all" ];
    };

    systemd.services.ollama-preload = {
      description = "Preload Ollama models for this machine's tier";
      after = [ "docker-ollama.service" "network-online.target" ];
      wants = [ "docker-ollama.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = preloadScript;
        RemainAfterExit = true;
      };
    };
  };
}
