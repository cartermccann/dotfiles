{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    google-workspace-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qmd = {
      url = "github:tobi/qmd";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    basic-memory = {
      url = "github:basicmachines-co/basic-memory/v0.22.1";
      flake = false;
    };
    playwright-cli = {
      url = "github:microsoft/playwright-cli";
      flake = false;
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Niri is the fallback session (Hyprland is the daily driver), so it tracks
    # niri-flake's release channel rather than a dev branch. The previous
    # `inputs.niri-unstable.url = ".../niri?ref=wip/branch"` override arrived
    # incidentally (de7e930) with no rationale, went five months without a lock
    # bump, and forced a from-source compile plus `doCheck = false` to get past
    # the branch's failing tests. niri-stable is cached and actually released.
    niri.url = "github:sodiboo/niri-flake";
    # Hyprland 0.55+ (Lua config). Pinned to a release tag; intentionally NOT
    # following nixpkgs so prebuilt artifacts hit hyprland.cachix.org rather than
    # forcing a local source compile (substituter added in modules/common.nix).
    hyprland = {
      url = "github:hyprwm/Hyprland?ref=v0.55.3&submodules=1";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
    };
    # Caelestia — the Quickshell-based shell behind the "Hyprland (Caelestia)"
    # session tile. Deliberately NOT following our nixpkgs: it targets
    # nixos-unstable and builds quickshell from a git checkout under
    # clangStdenv, so pinning it back to 25.11 risks a Qt mismatch in a package
    # that has no binary cache to fall back on. The duplicated nixpkgs costs
    # eval time, not a second copy of the system closure.
    caelestia = {
      url = "github:caelestia-dots/shell";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Claude Desktop repackaged for Linux (no official Nix support; official
    # Linux beta is apt-only). FHS variant needed so MCP servers can run
    # npx/uvx/docker.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr = {
      url = "github:ogulcancelik/herdr/v0.8.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
    };
    # Hardened SSH-only Korgo client. Pin the independently verified source
    # revision; do not follow this flake's nixpkgs because the package's fixed
    # Electron inputs were verified against its own lock file.
    korgo = {
      url = "github:cartermccann/korgo-bot/9518e85103a115fde20130170e7a15da3b63e6bc";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ./parts ];
    };
}
