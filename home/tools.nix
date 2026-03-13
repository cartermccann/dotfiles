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

    # Dev workflow
    lazygit
    lazydocker
    uv
    flyctl
    stripe-cli
    git-lfs
    mise
    google-cloud-sdk

    # Nix tooling
    nixfmt-rfc-style

    # AI / LLM
    opencode
    codex
    piper-tts

    # Networking
    whois
    inetutils
    netcat-openbsd

    # Google Workspace CLI
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
