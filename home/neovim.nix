{
  config,
  pkgs,
  user,
  ...
}:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    # 26.05 flipped both defaults to false; no plugin here uses either provider.
    withRuby = false;
    withPython3 = false;
    # HM 26.05 writes the provider toggles to nvim/init.lua, which collides
    # with the out-of-store nvim/ symlink below; load them via the wrapper.
    sideloadInitLua = true;
    extraPackages = with pkgs; [
      # LSP servers — Nix-provided so Mason isn't needed
      pyright
      typescript-language-server
      nixd
      elixir-ls
      zls
      rust-analyzer
      clang-tools
      jdt-language-server
    ];
  };

  # The Ouranos base16 slots for colors/palette.lua, generated from
  # lib/palette.nix so the editor can't drift from the desktop. Lives outside
  # nvim/ because that directory is the out-of-store symlink below.
  xdg.configFile."ouranos/palette.lua".text = (import ../lib/ouranos.nix).luaPalette;

  # Live-editable nvim config via symlink to dotfiles
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "/home/${user}/dotfiles/config/nvim";
}
