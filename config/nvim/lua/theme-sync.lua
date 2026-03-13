-- theme-sync.lua — live theme switching from ~/.config/theme/nvim-colorscheme
-- Called by theme-apply via nvim --remote-send, and also runs a file watcher

local M = {}

local state_file = vim.fn.expand("~/.config/theme/nvim-colorscheme")

function M.read_theme()
  local f = io.open(state_file, "r")
  if f then
    local theme = f:read("*l")
    f:close()
    if theme and theme ~= "" then
      return theme
    end
  end
  return nil
end

function M.apply(colorscheme)
  if not colorscheme then
    return
  end

  -- Ensure the colorscheme plugin is loaded (they may be lazy-loaded)
  local plugin_map = {
    ["catppuccin-mocha"] = "catppuccin",
    ["nord"] = "nord.nvim",
    ["tokyonight-night"] = "tokyonight.nvim",
    ["kanagawa-wave"] = "kanagawa.nvim",
    ["kanagawa"] = "kanagawa.nvim",
    ["gruvbox"] = "gruvbox.nvim",
    ["rose-pine"] = "rose-pine",
  }

  local plugin = plugin_map[colorscheme]
  if plugin then
    pcall(function()
      require("lazy").load({ plugins = { plugin } })
    end)
  end

  -- Apply the colorscheme
  local ok, err = pcall(vim.cmd.colorscheme, colorscheme)
  if not ok then
    vim.notify("theme-sync: failed to set " .. colorscheme .. ": " .. err, vim.log.levels.WARN)
  end
end

function M.sync()
  local theme = M.read_theme()
  if theme then
    M.apply(theme)
  end
end

-- Set up a file watcher using vim.uv (libuv)
function M.setup()
  -- Do an initial sync
  M.sync()

  -- Watch the state file for changes
  local uv = vim.uv or vim.loop
  local handle = uv.new_fs_event()
  if handle and vim.fn.filereadable(state_file) == 1 then
    handle:start(state_file, {}, function(err)
      if err then
        return
      end
      -- Schedule the colorscheme change on the main thread
      vim.schedule(function()
        M.sync()
      end)
    end)
  end
end

-- When required directly (e.g. from --remote-send), just sync immediately
M.sync()

return M
