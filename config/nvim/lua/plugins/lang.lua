-- Language extras and LSP configuration
return {
  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.elixir" },
  { import = "lazyvim.plugins.extras.lang.rust" },
  { import = "lazyvim.plugins.extras.lang.nix" },
  { import = "lazyvim.plugins.extras.lang.clangd" },
  { import = "lazyvim.plugins.extras.lang.zig" },
  { import = "lazyvim.plugins.extras.lang.java" },

  -- Use Nix-provided LSP binaries instead of Mason
  {
    "williamboman/mason.nvim",
    opts = { PATH = "append" },
  },
}
