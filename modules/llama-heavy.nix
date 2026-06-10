{ config, lib, ... }:

# "Heavy mode" — llama-server running a big MoE model with expert offload
# (FERRO-NEXT D7 power play). Ollama can't do this: expert-aware offload PRs
# (#12333, #15207) were closed unmerged, and its generic layer split is much
# slower for MoE. llama.cpp's --n-cpu-moe keeps the 3B active path in VRAM and
# parks cold experts in system RAM — Qwen3.6-35B-A3B at ~9 GB VRAM + ~15 GB
# RAM, ~20-25 tok/s expected on the RTX 5070.
#
# Docker for the same reason as ollama.nix: nixpkgs CUDA (cicc) crashes on
# Blackwell. NOT autostarted — it owns most of the GPU, so it's summoned via
# the `heavy` fish function (home/shell.nix), which swaps the ollama container
# out and this in. `heavy-stop` swaps back.
#
# First start downloads the GGUF (~24 GB) from HuggingFace into the
# llama-cache volume via llama-server's built-in -hf fetcher.
# ⚠ If the unsloth repo/quant tag changed, check:
#   https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF
# --n-cpu-moe 28 is a starting point: lower it until VRAM is ~full (faster),
# raise it if the server OOMs at load or long context.

{
  config = {
    virtualisation.oci-containers.containers.llama-heavy = {
      image = "ghcr.io/ggml-org/llama.cpp:server-cuda";
      ports = [ "127.0.0.1:8089:8089" ];
      volumes = [ "llama-cache:/root/.cache" ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
      cmd = [
        "-hf"
        "unsloth/Qwen3.6-35B-A3B-GGUF:Q4_K_M"
        "-ngl"
        "999"
        "--n-cpu-moe"
        "28"
        "-c"
        "32768"
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--jinja"
        "--host"
        "0.0.0.0"
        "--port"
        "8089"
      ];
    };

    # oci-containers wires every container into multi-user.target; heavy mode
    # must NOT start at boot — it would hold ~9 GB VRAM permanently.
    # Keep both names here because the unit prefix follows the OCI backend.
    systemd.services.docker-llama-heavy.wantedBy = lib.mkForce [ ];
    systemd.services.podman-llama-heavy.wantedBy = lib.mkForce [ ];
  };
}
