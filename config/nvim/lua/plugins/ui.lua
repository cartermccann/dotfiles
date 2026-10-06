-- UI: snacks does the heavy lifting (picker, explorer, dashboard, notifier,
-- input, indent guides, smooth scroll). One filename display (the
-- statusline), one motion layer (snacks.scroll), one scope guide.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true, style = "compact", top_down = false },
      picker = { enabled = true, layout = { preset = "default" } },
      explorer = { enabled = true, replace_netrw = true },
      words = { enabled = true },
      scope = { enabled = true },
      statuscolumn = { enabled = true },
      -- one dim guide; the current scope a shade brighter (colors/palette.lua)
      indent = { enabled = true, animate = { enabled = false } },
      scroll = {
        enabled = true,
        animate = { duration = { step = 10, total = 160 }, easing = "outQuad" },
      },
      dashboard = {
        enabled = true,
        preset = {
          header = [[
░█▀█░█▀▀░█▀█░█░█░▀█▀░█▄█
░█░█░█▀▀░█░█░▀▄▀░░█░░█░█
░▀░▀░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░▀]],
          keys = {
            { icon = "󰈞 ", key = "f", desc = "Find file", action = ":lua Snacks.picker.files()" },
            { icon = "󰱼 ", key = "g", desc = "Grep", action = ":lua Snacks.picker.grep()" },
            { icon = "󰋚 ", key = "r", desc = "Recent", action = ":lua Snacks.picker.recent()" },
            { icon = "󰦛 ", key = "s", desc = "Restore session", section = "session" },
            { icon = "󰊢 ", key = "G", desc = "Lazygit", action = ":lua Snacks.lazygit()" },
            { icon = "󰒓 ", key = "c", desc = "Config", action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = "󰗼 ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      win = { border = "single" },
      spec = {
        { "<leader>a", group = "agents" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "file" },
        { "<leader>g", group = "git" },
        { "<leader>gd", group = "diffview" },
        { "<leader>q", group = "quit/session" },
        { "<leader>s", group = "search" },
        { "<leader>u", group = "toggle" },
        { "<leader>x", group = "diagnostics" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "goto" },
      },
    },
  },

  -- icons for everything that asks nvim-web-devicons
  {
    "echasnovski/mini.icons",
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- hex colours rendered inline (replaces nvim-colorizer)
  {
    "echasnovski/mini.hipatterns",
    event = { "BufReadPost", "BufNewFile" },
    opts = function()
      return { highlighters = { hex_color = require("mini.hipatterns").gen_highlighter.hex_color() } }
    end,
  },
}
