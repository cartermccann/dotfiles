{
  config,
  pkgs,
  google-workspace-cli,
  ...
}:

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
    nodejs
    lazygit
    lazydocker
    uv
    flyctl
    stripe-cli
    git-lfs
    mise
    google-cloud-sdk
    awscli2

    # Nix tooling
    nixfmt-rfc-style

    # AI / LLM
    opencode
    codex
    piper-tts

    # Recording
    obs-studio

    # Networking
    whois
    inetutils
    netcat-openbsd

    # Google Workspace CLI
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
