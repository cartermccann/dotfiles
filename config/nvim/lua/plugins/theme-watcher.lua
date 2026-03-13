-- Theme file watcher — starts theme-sync on VimEnter
return {
  {
    dir = vim.fn.stdpath("config"),
    name = "theme-watcher",
    lazy = false,
    config = function()
      -- Defer to avoid racing with colorscheme loading
      vim.defer_fn(function()
        local ok, sync = pcall(require, "theme-sync")
        if ok then
          sync.setup()
        end
      end, 100)
    end,
  },
}
