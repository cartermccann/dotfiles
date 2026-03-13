-- UI configuration - Catppuccin Mocha colorscheme
return {
  -- Disable Nord
  { "shaunsingh/nord.nvim", enabled = false },

  -- Catppuccin Mocha
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        blink_cmp = true,
        flash = true,
        diffview = true,
        gitsigns = true,
        indent_blankline = { enabled = true, scope_color = "lavender" },
        lsp_trouble = true,
        mason = true,
        noice = true,
        neotree = true,
        rainbow_delimiters = true,
        snacks = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
      custom_highlights = function(colors)
        return {
          NonText = { fg = colors.overlay0 },
          Conceal = { fg = colors.overlay0 },
          WinSeparator = { fg = colors.lavender },
          CursorLine = { bg = colors.surface0 },
          Directory = { fg = colors.lavender },
          NeoTreeDirectoryIcon = { fg = colors.lavender },
          NeoTreeDirectoryName = { fg = colors.lavender },
          NeoTreeRootName = { fg = colors.lavender, bold = true },
          NeoTreeFileName = { fg = colors.text },
          NeoTreeGitModified = { fg = colors.blue },
          NeoTreeGitDirty = { fg = colors.blue },
          NeoTreeGitUntracked = { fg = colors.teal },
        }
      end,
    },
  },

  -- Neo-tree: disable git-status name coloring (the peach/orange look)
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      default_component_configs = {
        git_status = {
          symbols = {
            modified = "",
          },
        },
        name = {
          highlight_opened_files = true,
        },
      },
      renderers = {
        file = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = false },
          { "git_status", highlight = "NeoTreeDimText" },
        },
        directory = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = false },
          { "git_status", highlight = "NeoTreeDimText" },
        },
      },
    },
  },

  -- Diffview: side-by-side diffs and merge conflict resolution
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current)" },
      { "<leader>gdH", "<cmd>DiffviewFileHistory<cr>", desc = "File History (all)" },
    },
  },

  -- Set Catppuccin as the LazyVim colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-nvim",
    },
  },
}
