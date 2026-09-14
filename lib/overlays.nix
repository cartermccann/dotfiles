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
  # Backport GNOME Keyring !112: fresh Secret Service clients can otherwise
  # crash the daemon and trigger repeated unlock prompts. See the local README.
  (final: prev: {
    gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../pkgs/gnome-keyring/fix-client-race.patch ];
    });
  })
]
