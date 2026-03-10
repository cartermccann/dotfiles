{ config, lib, pkgs, google-workspace-cli, ... }:

{
  environment.systemPackages = with pkgs; [
    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv
    pyright

    # JavaScript / Node
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.npm

    # Elixir
    elixir
    erlang
    elixir-ls

    # Zig
    zig
    zls

    # C / C++
    gcc
    gnumake
    cmake
    clang-tools
    llvm

    # Rust
    rustup
    rust-analyzer

    # Java
    jdt-language-server

    # Ruby
    ruby

    # Go
    go

    # Nix
    nil
    nixfmt-rfc-style

    # Google Workspace CLI
    google-workspace-cli.packages.x86_64-linux.default

    # Version management
    mise

    # AI / LLM CLI tools
    # claude-code     # install via npm: npm install -g @anthropic-ai/claude-code
    # gemini-cli      # check nixpkgs availability
    opencode

    # General dev tools
    ripgrep
    fd
    fzf
    jq
    yq
    tree
    bat
    eza
    dust
    tldr
    lazygit
    lazydocker
    tmux
    docker-compose
    stripe-cli
    gh
    git-lfs
    tree-sitter

    # Networking tools
    curl
    wget
    whois
    inetutils
    openbsd-netcat
  ];

  # Docker
  virtualisation.docker.enable = true;
}
