return {
  -- Completion menu. Accepts on <CR>/<C-y>; <Tab> belongs to the minuet ghost
  -- text first (lua/plugins/ai.lua adds that to this keymap).
  {
    "saghen/blink.cmp",
    version = "1.*", -- tagged releases ship the prebuilt fuzzy matcher
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "enter", ["<C-y>"] = { "select_and_accept" } },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        accept = { auto_brackets = { enabled = true } },
        menu = { draw = { treesitter = { "lsp" } } },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = false }, -- minuet owns inline ghost text
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      cmdline = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  { "folke/lazydev.nvim", ft = "lua", opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } } },

  { "echasnovski/mini.pairs", event = "VeryLazy", opts = { modes = { insert = true, command = true } } },
  { "echasnovski/mini.surround", keys = { "gsa", "gsd", "gsr", "gsf", "gsh" }, opts = {
    mappings = { add = "gsa", delete = "gsd", replace = "gsr", find = "gsf", highlight = "gsh" },
  } },

  -- a/i textobjects; f/c come from treesitter (nvim-treesitter-textobjects queries)
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
        },
      }
    end,
  },

  -- comment strings that follow the treesitter language (JSX, Vue, etc.)
  { "folke/ts-comments.nvim", event = "VeryLazy", opts = {} },

  -- formatting: every formatter is on PATH from home/neovim.nix
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format" },
      {
        "<leader>uf",
        function()
          vim.g.autoformat = vim.g.autoformat == false
          vim.notify("Format on save: " .. (vim.g.autoformat ~= false and "on" or "off"))
        end,
        desc = "Toggle format on save",
      },
    },
    opts = {
      default_format_opts = { lsp_format = "fallback" },
      format_on_save = function()
        if vim.g.autoformat == false then return end
        return { timeout_ms = 1500 }
      end,
      formatters_by_ft = {
        lua = { "stylua" },
        nix = { "nixfmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        go = { "gofumpt" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        javascript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescript = { "prettierd" },
        typescriptreact = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        css = { "prettierd" },
        html = { "prettierd" },
        markdown = { "prettierd" },
        yaml = { "prettierd" },
      },
    },
  },
}
