-- UI configuration
return {
  -- Nord colorscheme
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 1000,
  },

  -- Set Nord as the LazyVim colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nord",
    },
  },
}
