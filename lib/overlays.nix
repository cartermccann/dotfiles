{ inputs }:
[
  inputs.niri.overlays.niri
  (final: prev: {
    ghostty = inputs.ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
  })
  # Stable neovim 0.12.x from the unstable channel (25.11 ships 0.11.7).
  (final: prev: {
    neovim-unwrapped =
      inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.neovim-unwrapped;
  })
]
