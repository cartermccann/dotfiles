-- User keymaps. LazyVim loads this AFTER its own defaults, so maps here win.

-- <leader>uh — toggle palette background transparency.
-- NOTE: overrides LazyVim's default inlay-hints toggle (also <leader>uh).
-- The palette colorscheme reads `vim.g.palette_transparent` (default true) at load,
-- so flipping the flag and re-sourcing the scheme swaps solid/transparent bg.
vim.keymap.set("n", "<leader>uh", function()
  if not (vim.g.colors_name or ""):match("^palette") then
    vim.notify("Transparency toggle only applies to the palette theme", vim.log.levels.WARN)
    return
  end
  local cur = vim.g.palette_transparent
  if cur == nil then
    cur = true
  end
  vim.g.palette_transparent = not cur
  vim.cmd("colorscheme palette")
  vim.notify("Palette transparency: " .. (vim.g.palette_transparent and "on" or "off"))
end, { desc = "Toggle palette transparency" })
