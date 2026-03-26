{ config, pkgs, user, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      # LSP servers — Nix-provided so Mason isn't needed
      pyright
      nodePackages.typescript-language-server
      nixd
      elixir-ls
      zls
      rust-analyzer
      clang-tools
      jdt-language-server
    ];
  };

  # Live-editable nvim config via symlink to dotfiles
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "/home/${user}/dotfiles/config/nvim";
}
