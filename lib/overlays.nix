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
  # Backport Waybar #5165 (c19abf3): the mpris module hid its widget straight
  # from a playerctl callback and segfaulted when a player stopped (seen here
  # 2026-10-06; upstream #5124). Unreleased as of 0.15.0; drop once nixpkgs
  # ships a release that contains it.
  (final: prev: {
    waybar = prev.waybar.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (final.fetchpatch {
          url = "https://github.com/Alexays/Waybar/commit/c19abf373bceb3eb264690f94d367407d7133568.patch";
          hash = "sha256-yRsqQZRqP+qClLsJ/WOp0NkvYqLECNl7ylndS9Kva+4=";
        })
      ];
    });
  })
  # Backport GNOME Keyring !112: fresh Secret Service clients can otherwise
  # crash the daemon and trigger repeated unlock prompts. See the local README.
  (final: prev: {
    gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../pkgs/gnome-keyring/fix-client-race.patch ];
    });
  })
]
