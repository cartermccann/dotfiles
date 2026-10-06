-- Language/LSP overrides
return {
  -- Use Nix-provided LSP binaries instead of Mason
  {
    "mason-org/mason.nvim",
    opts = { PATH = "append" },
  },
  -- Copilot was "removed" (ai.lua) but its server stayed installed in Mason,
  -- and LazyVim auto-enables every installed server, so it kept attaching to
  -- buffers with telemetry on. enabled = false is LazyVim's opt-out.
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { copilot = { enabled = false } } },
  },
}
