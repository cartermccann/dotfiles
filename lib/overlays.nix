{ inputs }:
[
  inputs.niri.overlays.niri
  (final: prev: {
    ghostty = inputs.ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
  })
  # Stable neovim 0.12.x from the unstable channel (25.11 ships 0.11.7).
  # Replaced the nightly overlay 2026-06-09: the locked nightly was a stale
  # pre-0.12.0 build, and updating it would have jumped to 0.13.0-dev.
  (final: prev: {
    neovim-unwrapped =
      inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.neovim-unwrapped;
  })
]
