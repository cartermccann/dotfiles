-- Global keymaps. These follow LazyVim's layout, so the muscle memory from the
-- distro carries over; LSP maps live in lua/lsp.lua, plugin maps in their specs.
local map = vim.keymap.set

-- movement over wrapped lines
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- windows
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Taller" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Shorter" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Narrower" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Wider" })
map("n", "<leader>-", "<C-w>s", { desc = "Split below" })
map("n", "<leader>|", "<C-w>v", { desc = "Split right" })
map("n", "<leader>wd", "<C-w>c", { desc = "Close window" })

-- buffers (no tabline: the picker is the buffer list)
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Alternate buffer" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete other buffers" })

-- editing
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("v", "<", "<gv")
map("v", ">", ">gv")
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save" })
map({ "i", "n", "s" }, "<esc>", function()
  vim.cmd("noh")
  return "<esc>"
end, { expr = true, desc = "Escape and clear search" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- diagnostics
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Prev diagnostic" })
map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = "ERROR", float = true }) end, { desc = "Next error" })
map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = "ERROR", float = true }) end, { desc = "Prev error" })

-- find / search (snacks.picker)
local P = function(name, opts)
  return function() Snacks.picker[name](opts) end
end
map("n", "<leader><space>", P("smart"), { desc = "Find files (smart)" })
map("n", "<leader>ff", P("files"), { desc = "Find files" })
map("n", "<leader>fr", P("recent"), { desc = "Recent files" })
map("n", "<leader>fc", P("files", { cwd = vim.fn.stdpath("config") }), { desc = "Config files" })
map("n", "<leader>,", P("buffers"), { desc = "Buffers" })
map("n", "<leader>/", P("grep"), { desc = "Grep" })
map("n", "<leader>sg", P("grep"), { desc = "Grep" })
map({ "n", "x" }, "<leader>sw", P("grep_word"), { desc = "Grep word/selection" })
map("n", "<leader>sh", P("help"), { desc = "Help" })
map("n", "<leader>sk", P("keymaps"), { desc = "Keymaps" })
map("n", "<leader>sd", P("diagnostics"), { desc = "Diagnostics" })
map("n", "<leader>sR", P("resume"), { desc = "Resume last search" })
map("n", "<leader>st", P("grep", { search = [[\b(TODO|FIXME|HACK|NOTE)\b]], regex = true }), { desc = "Todo comments" })
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "Explorer" })
map("n", "<leader>n", function() Snacks.notifier.show_history() end, { desc = "Notification history" })
map("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss notifications" })

-- git
map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<leader>gs", P("git_status"), { desc = "Git status" })
map("n", "<leader>gl", P("git_log"), { desc = "Git log" })
map("n", "<leader>gb", P("git_log_line"), { desc = "Git log (line)" })
map({ "n", "x" }, "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Open on GitHub" })

-- toggles
map("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end, { desc = "Toggle wrap" })
map("n", "<leader>uH", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, { desc = "Toggle inlay hints" })

-- <leader>uh — toggle palette background transparency. The colorscheme reads
-- `vim.g.palette_transparent` (default true) at load, so flipping the flag and
-- re-sourcing it swaps solid/transparent. (Inlay hints moved to <leader>uH.)
map("n", "<leader>uh", function()
  if not (vim.g.colors_name or ""):match("^palette") then
    vim.notify("Transparency toggle only applies to the palette theme", vim.log.levels.WARN)
    return
  end
  local cur = vim.g.palette_transparent
  if cur == nil then cur = true end
  vim.g.palette_transparent = not cur
  vim.cmd("colorscheme palette")
  vim.notify("Palette transparency: " .. (vim.g.palette_transparent and "on" or "off"))
end, { desc = "Toggle palette transparency" })
