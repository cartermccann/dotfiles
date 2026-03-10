{ config, pkgs, ... }:

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
      nil
      elixir-ls
      zls
      rust-analyzer
      clang-tools
    ];
  };

  # Bootstrap LazyVim
  xdg.configFile."nvim/init.lua".text = ''
    -- Bootstrap lazy.nvim
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
      vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
      })
    end
    vim.opt.rtp:prepend(lazypath)

    -- LazyVim setup
    require("lazy").setup({
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        -- Language extras
        { import = "lazyvim.plugins.extras.lang.python" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        { import = "lazyvim.plugins.extras.lang.elixir" },
        { import = "lazyvim.plugins.extras.lang.rust" },
        { import = "lazyvim.plugins.extras.lang.nix" },
        { import = "lazyvim.plugins.extras.lang.clangd" },
        { import = "lazyvim.plugins.extras.lang.zig" },
        -- Use Nix-provided LSP binaries instead of Mason
        {
          "williamboman/mason.nvim",
          opts = { PATH = "append" },
        },
      },
      defaults = { lazy = false, version = false },
      install = { colorscheme = { "tokyonight", "habamax" } },
      checker = { enabled = true },
      performance = {
        rtp = {
          disabled_plugins = {
            "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
          },
        },
      },
    })
  '';
}
