-- AI layer (FERRO-NEXT D3, 2026-06-09). One tool per layer:
--   completion menu  blink.cmp (LazyVim default; accepts on <CR>/<C-y>, never Tab)
--   ghost text + NES copilot-native + sidekick extras (lazyvim.json; Tab accepts)
--   agent            Claude Code in its tmux pane, bridged in via claudecode.nvim
-- Replaced gen.nvim/ollama — superseded by the above.
return {
  -- ghost-text mode: AI suggestions render inline, not as a blink menu source
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.g.ai_cmp = false
    end,
  },

  -- WebSocket MCP bridge: nvim hosts the server, the Claude Code CLI in tmux
  -- connects via `/ide` — selection/buffer context flows over, diffs come back
  -- as native nvim diff views. terminal.provider=none keeps Claude in tmux.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      terminal = { provider = "none" },
    },
    keys = {
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add buffer to Claude context" },
      { "<leader>cd", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
      { "<leader>cD", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject Claude diff" },
    },
  },
}
