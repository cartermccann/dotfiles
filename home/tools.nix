{
  config,
  pkgs,
  google-workspace-cli,
  fenix,
  ...
}:
let
  rust-toolchain = fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.withComponents [
    "cargo"
    "clippy"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "rust-src"
  ];
in

{
  home.packages = with pkgs; [
    # Modern CLI
    ripgrep
    fd
    jq
    yq
    tree
    eza
    dust
    tldr
    tree-sitter
    yazi
    cava

    # Dev workflow
    nodejs_24
    lazygit
    lazydocker
    uv
    flyctl
    stripe-cli
    git-lfs
    google-cloud-sdk
    awscli2

    rust-toolchain

    # Nix tooling
    nixfmt-rfc-style
    nh
    nix-output-monitor

    # AI / LLM
    opencode
    codex

    # Recording
    obs-studio

    # Networking
    whois
    netcat-openbsd

    # Google Workspace CLI
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
