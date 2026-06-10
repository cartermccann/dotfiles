-- User keymaps. LazyVim loads this AFTER its own defaults, so maps here win.

-- <leader>uh — toggle ferro background transparency.
-- NOTE: overrides LazyVim's default inlay-hints toggle (also <leader>uh).
-- The ferro colorscheme reads `vim.g.ferro_transparent` (default true) at load,
-- so flipping the flag and re-sourcing the scheme swaps solid/transparent bg.
vim.keymap.set("n", "<leader>uh", function()
  if not (vim.g.colors_name or ""):match("^ferro") then
    vim.notify("Transparency toggle only applies to the ferro theme", vim.log.levels.WARN)
    return
  end
  local cur = vim.g.ferro_transparent
  if cur == nil then
    cur = true
  end
  vim.g.ferro_transparent = not cur
  vim.cmd("colorscheme ferro")
  vim.notify("Ferro transparency: " .. (vim.g.ferro_transparent and "on" or "off"))
end, { desc = "Toggle ferro transparency" })
