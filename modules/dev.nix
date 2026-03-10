{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Python
    python3
    python3Packages.pip
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

    # C
    gcc
    gnumake
    cmake
    clang-tools

    # Rust
    rustup
    rust-analyzer

    # Nix
    nil
    nixfmt-rfc-style

    # General dev tools
    ripgrep
    fd
    fzf
    jq
    tree
    bat
    eza
    lazygit
    lazydocker
    tmux
    docker-compose
  ];
}
