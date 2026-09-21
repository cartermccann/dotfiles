{
  pkgs,
  qmd,
}:

let
  base = qmd.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
base.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.autoPatchelfHook ];
  buildInputs = (old.buildInputs or [ ]) ++ [
    pkgs.stdenv.cc.cc.lib
    # node-llama-cpp's prebuilt Vulkan backend links libvulkan.so.1. The
    # loader finds the NVIDIA ICD via /run/opengl-driver/share/vulkan/icd.d.
    pkgs.vulkan-loader
  ];

  installPhase = old.installPhase + ''
    # node-llama-cpp ships prebuilt native bindings, but upstream's QMD flake
    # does not patch them for NixOS. Keep the CPU package (fallback) and the
    # Vulkan package (GPU); drop foreign arches and the CUDA variants, whose
    # prebuilt binaries want the CUDA 13 runtime (libcudart/libcublas .so.13).
    # 2026-09-21: switched from CPU-only to Vulkan on kronos (RTX 5070).
    find "$out/lib/qmd/node_modules/@node-llama-cpp" -mindepth 1 -maxdepth 1 \
      ! -name linux-x64 ! -name linux-x64-vulkan -exec rm -rf {} +
    rm -rf "$out/lib/qmd/node_modules/@reflink/reflink-linux-x64-musl"

    # Pin the backend so node-llama-cpp neither probes absent CUDA packages nor
    # attempts a runtime source build inside the immutable Nix store. QMD falls
    # back to the CPU binding by itself if Vulkan init fails.
    wrapProgram "$out/bin/qmd" --set QMD_LLAMA_GPU vulkan
  '';
})
