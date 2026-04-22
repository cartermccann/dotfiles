{ inputs }:
[
  inputs.niri.overlays.niri
  (final: prev: {
    ghostty = inputs.ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
  })
  # Caelestia ships a git-HEAD quickshell whose moc segfaults when built
  # against our Qt. Swap in nixpkgs' cached quickshell (same 0.2.1).
  (final: prev: {
    caelestia-shell-with-cli =
      (inputs.caelestia-shell.packages.${prev.stdenv.hostPlatform.system}.caelestia-shell.override {
        quickshell = final.quickshell;
      }).override { withCli = true; };
  })
  inputs.neovim-nightly-overlay.overlays.default
]
