return {
  -- Only a source of lsp/<server>.lua defaults now: lua/lsp.lua configures and
  -- enables servers with nvim's built-in vim.lsp.config/enable.
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function() require("lsp").setup() end,
  },

  -- Rust: rustaceanvim runs rust-analyzer itself (so lua/lsp.lua skips it).
  { "mrcjkb/rustaceanvim", ft = "rust" },
  { "saecki/crates.nvim", event = "BufRead Cargo.toml", opts = { completion = { crates = { enabled = true } } } },
}
