return {
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote flash" },
    },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix" },
      { "<leader>cS", "<cmd>Trouble lsp toggle<cr>", desc = "LSP references/defs" },
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { headerMaxWidth = 80 },
    keys = {
      {
        "<leader>sr",
        function()
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          require("grug-far").open({ prefills = { filesFilter = ext and ext ~= "" and "*." .. ext or nil } })
        end,
        mode = { "n", "v" },
        desc = "Search and replace",
      },
    },
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save session" },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(buf)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = buf, desc = desc }) end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<cr>", "Stage hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<cr>", "Reset hunk")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>ghB", function() gs.blame() end, "Blame buffer")
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview open" },
      { "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current)" },
      { "<leader>gdH", "<cmd>DiffviewFileHistory<cr>", desc = "File history (all)" },
    },
  },
}
