local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  -- Lazy by default: each spec says what loads it.
  defaults = { lazy = true, version = false },
  install = { colorscheme = { "palette" } },
  -- No background git fetches every session; update on purpose with :Lazy.
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  ui = { border = "single" },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})

pcall(vim.cmd.colorscheme, "palette")
