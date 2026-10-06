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
-- opts may be a function, so values like the file's dir are read at press time
local P = function(name, opts)
  return function() Snacks.picker[name](type(opts) == "function" and opts() or opts) end
end
local here = function() return { cwd = vim.fn.expand("%:p:h") } end
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

-- ── The rest of LazyVim's defaults, so muscle memory keeps working ──────────

-- terminal
map({ "n", "t" }, "<C-/>", function() Snacks.terminal() end, { desc = "Terminal" })
map({ "n", "t" }, "<C-_>", function() Snacks.terminal() end, { desc = "which_key_ignore" }) -- <C-/> as tmux sends it
map("n", "<leader>ft", function() Snacks.terminal() end, { desc = "Terminal" })
map("n", "<leader>fT", function() Snacks.terminal(nil, here()) end, { desc = "Terminal (file dir)" })

-- files / buffers
map("n", "<leader>fb", P("buffers"), { desc = "Buffers" })
map("n", "<leader>fg", P("git_files"), { desc = "Git files" })
map("n", "<leader>fF", P("files", here), { desc = "Files (file dir)" })
map("n", "<leader>fR", P("recent", { filter = { cwd = true } }), { desc = "Recent (cwd)" })
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Alternate buffer" })
map("n", "<leader>bD", "<cmd>bd<cr>", { desc = "Delete buffer and window" })

-- misc
map("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })
map("n", "<leader>:", P("command_history"), { desc = "Command history" })
map("n", "<leader>?", function() require("which-key").show({ global = false }) end, { desc = "Buffer keymaps" })
map("n", "<leader>.", function() Snacks.scratch() end, { desc = "Scratch buffer" })
map("n", "<leader>S", function() Snacks.scratch.select() end, { desc = "Select scratch" })
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Comment below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Comment above" })

-- search
map("n", "<leader>sb", P("lines"), { desc = "Buffer lines" })
map("n", "<leader>sB", P("grep_buffers"), { desc = "Grep open buffers" })
map("n", "<leader>sc", P("command_history"), { desc = "Command history" })
map("n", "<leader>sC", P("commands"), { desc = "Commands" })
map("n", "<leader>sD", P("diagnostics_buffer"), { desc = "Buffer diagnostics" })
map("n", "<leader>sG", P("grep", here), { desc = "Grep (file dir)" })
map({ "n", "x" }, "<leader>sW", P("grep_word", here), { desc = "Grep word (file dir)" })
map("n", "<leader>sj", P("jumps"), { desc = "Jumps" })
map("n", "<leader>sm", P("marks"), { desc = "Marks" })
map("n", "<leader>sl", P("loclist"), { desc = "Location list" })
map("n", "<leader>sq", P("qflist"), { desc = "Quickfix list" })
map("n", "<leader>sH", P("highlights"), { desc = "Highlights" })
map("n", "<leader>sM", P("man"), { desc = "Man pages" })
map("n", "<leader>sa", P("autocmds"), { desc = "Autocmds" })
map("n", "<leader>si", P("icons"), { desc = "Icons" })
map("n", "<leader>su", P("undo"), { desc = "Undo history" })
map("n", '<leader>s"', P("registers"), { desc = "Registers" })
map("n", "<leader>s/", P("search_history"), { desc = "Search history" })

-- toggles
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.option("relativenumber", { name = "Relative number" }):map("<leader>uL")
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("conceallevel", { off = 0, on = 2 }):map("<leader>uc")
Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark background" }):map("<leader>ub")
Snacks.toggle.treesitter():map("<leader>uT")
Snacks.toggle.indent():map("<leader>ug")
Snacks.toggle.dim():map("<leader>uD")
Snacks.toggle.zen():map("<leader>uz")
Snacks.toggle.zoom():map("<leader>uZ")
Snacks.toggle.zoom():map("<leader>wm")
Snacks.toggle.scroll():map("<leader>uS")
map("n", "<leader>uC", P("colorschemes"), { desc = "Colorschemes" })
map("n", "<leader>ur", "<cmd>nohlsearch<bar>diffupdate<bar>normal! <C-L><cr>", { desc = "Redraw / clear" })
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect position" })
map("n", "<leader>uI", function() vim.treesitter.inspect_tree() vim.api.nvim_input("I") end, { desc = "Inspect tree" })
map("n", "<leader>uF", function()
  vim.b.autoformat = vim.b.autoformat == false
  vim.notify("Format on save (buffer): " .. (vim.b.autoformat ~= false and "on" or "off"))
end, { desc = "Toggle format on save (buffer)" })

-- diagnostics lists
map("n", "<leader>xl", function()
  local ok = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
  if not ok then vim.notify("No location list", vim.log.levels.WARN) end
end, { desc = "Location list" })
map("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list (Trouble)" })
map("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix (Trouble)" })
map("n", "<leader>cs", "<cmd>Trouble symbols toggle<cr>", { desc = "Symbols (Trouble)" })

-- git
map("n", "<leader>gf", P("git_log_file"), { desc = "File history" })
map("n", "<leader>gL", P("git_log", here), { desc = "Git log (file dir)" })
map("n", "<leader>gS", P("git_stash"), { desc = "Git stash" })
map("n", "<leader>gD", P("git_diff"), { desc = "Git diff (hunks)" })
map("n", "<leader>gi", P("gh_issue"), { desc = "GitHub issues (open)" })
map("n", "<leader>gI", P("gh_issue", { state = "all" }), { desc = "GitHub issues (all)" })
map("n", "<leader>gp", P("gh_pr"), { desc = "GitHub PRs (open)" })
map("n", "<leader>gP", P("gh_pr", { state = "all" }), { desc = "GitHub PRs (all)" })
map("n", "<leader>gG", function() Snacks.lazygit(here()) end, { desc = "Lazygit (file dir)" })
map({ "n", "x" }, "<leader>gY", function()
  Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
end, { desc = "Copy GitHub URL" })

-- tabs
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Prev tab" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First tab" })
map("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last tab" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close other tabs" })
