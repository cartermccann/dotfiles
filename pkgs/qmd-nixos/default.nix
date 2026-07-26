{
  pkgs,
  qmd,
}:

let
  base = qmd.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
base.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.autoPatchelfHook ];
  buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.stdenv.cc.cc.lib ];

  installPhase = old.installPhase + ''
    # node-llama-cpp ships prebuilt native bindings, but upstream's QMD flake
    # does not patch them for NixOS. Keep the deterministic CPU package and
    # discard optional foreign/CUDA/Vulkan binaries before autoPatchelf runs.
    find "$out/lib/qmd/node_modules/@node-llama-cpp" -mindepth 1 -maxdepth 1 \
      ! -name linux-x64 -exec rm -rf {} +
    rm -rf "$out/lib/qmd/node_modules/@reflink/reflink-linux-x64-musl"

    # Do not let node-llama-cpp probe absent GPU packages and attempt a runtime
    # source build inside the immutable Nix store.
    wrapProgram "$out/bin/qmd" --set QMD_FORCE_CPU 1
  '';
})
