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
    # Languages (globally available)
    python3
    go

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
    glow # markdown reader
    xh # modern httpie
    ouch # universal compress/decompress
    duf # prettier df
    procs # modern ps
    bandwhich # per-process network bandwidth
    doggo # DNS lookup
    gping # graphical ping

    # Dev workflow tools
    just # command runner
    watchexec # file watcher
    tokei # code statistics
    hyperfine # CLI benchmarking
    sd # modern sed

    # Rice
    pipes-rs
    cbonsai

    # Dev workflow
    nodejs_24
    bun
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
