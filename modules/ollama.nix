{
  config,
  lib,
  pkgs,
  ...
}:

# Ollama via Docker
# On GPU hosts: uses nvidia-container-toolkit for CUDA acceleration
# On CPU hosts: runs without GPU passthrough
# Avoids nixpkgs CUDA build issues (cicc crash on Blackwell/RTX 5070)

let
  # Loadout research 2026-06-09 (FERRO-NEXT D7): budget ~10 GB of the 12 GB
  # VRAM, ~2 GB headroom for compositor/ghostty. Prefer Gemma 4 / Qwen-family
  # models; avoid Gemma 3 as the default. QAT tags preferred over post-hoc Q4
  # quants whenever they exist (trained-to-be-quantized).
  # Preload only ever adds — retire old models manually via `ollama rm`.
  modelsByTier = {
    high = [
      "gemma4:12b-it-qat" # daily chat default: 7.2 GB, Gemma 4, fits 12 GB better than q8
      "hf.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF:Q4_K_M" # Qwythos 9B GGUF, 5.63 GB; reasoning/tool-calling test model
      "qwen2.5-coder:3b-base" # FIM tab-completion (minuet): 1.9 GB, stays resident
      "qwen3.5:4b" # quick jobs (dictation cleanup, summaries): 3.4 GB
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
        if ! RESPONSE=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/pull -d '{"name": "${model}", "stream": false}'); then
          echo "Failed to pull ${model}: curl request failed"
          continue
        fi
        if echo "$RESPONSE" | ${pkgs.jq}/bin/jq -e '.error? // empty' > /dev/null; then
          echo "Failed to pull ${model}:"
          echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.error'
          continue
        fi
        echo "Done: ${model}"
      fi
    '') models}

    echo "Model preload complete."
  '';
in
{
  options.local.ollamaTier = lib.mkOption {
    type = lib.types.enum [
      "low"
      "medium"
      "high"
    ];
    default = "medium";
    description = "Hardware tier for Ollama model selection";
  };

  config = {
    virtualisation.oci-containers.containers.ollama = {
      # Pin the engine: unpinned :latest let a stale cached image (0.17.7) come
      # back on restart and fail to load gemma4 ("unknown model architecture").
      # Bump this deliberately when a new model needs a newer engine.
      image = "ollama/ollama:0.30.10";
      ports = [ "127.0.0.1:11434:11434" ]; # was 0.0.0.0 — nothing remote calls it
      volumes = [ "ollama:/root/.ollama" ];
      environment = {
        OLLAMA_FLASH_ATTENTION = "1"; # prerequisite for KV quant; free VRAM+speed
        OLLAMA_KV_CACHE_TYPE = "q8_0"; # halves KV memory, negligible quality cost
        OLLAMA_CONTEXT_LENGTH = "16384"; # default is only 4096
        OLLAMA_KEEP_ALIVE = "30m"; # default 5m unloads mid-session
        OLLAMA_MAX_LOADED_MODELS = "1"; # one 7–9 GB model resident; avoid 12 GB VRAM clown-car mode
      };
      extraOptions = lib.optionals hasGpu [ "--device=nvidia.com/gpu=all" ];
    };

    systemd.services.ollama-preload = {
      description = "Preload Ollama models for this machine's tier";
      after = [
        "podman-ollama.service"
        "network-online.target"
      ];
      wants = [
        "podman-ollama.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = preloadScript;
        RemainAfterExit = true;
      };
    };
  };
}
