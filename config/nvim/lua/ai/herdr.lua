-- Send code to the Codex or Claude Code agent running in the same project's
-- herdr workspace (see home/hyprland/projects.nix for the layout). herdr
-- already knows which pane holds which agent, so this asks it rather than
-- tracking panes itself, and `herdr agent prompt` handles bracketed paste.
local M = {}

local function project_root()
  local root = vim.fs.root(0, ".git")
  return root or vim.fn.getcwd()
end

-- The agent of `kind` whose working directory is inside this project,
-- preferring one that's ready for input.
local function find_agent(kind)
  local out = vim.fn.system({ "herdr", "agent", "list" })
  local ok, data = pcall(vim.json.decode, out)
  if not ok or not data.result then return nil, "herdr isn't running" end
  local root, best = project_root(), nil
  for _, a in ipairs(data.result.agents or {}) do
    -- exact repo or a subdirectory; a bare prefix would also match the
    -- `gwa` sibling worktrees (repo--branch)
    if a.agent == kind and a.cwd and (a.cwd == root or vim.startswith(a.cwd, root .. "/")) then
      if a.agent_status == "idle" or a.agent_status == "done" then return a end
      best = best or a
    end
  end
  if best then return best end
  return nil, ("no %s agent in %s"):format(kind, vim.fn.fnamemodify(root, ":t"))
end

-- `@path#L10-24` reference for the current line or visual selection.
local function code_ref()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    if a > b then a, b = b, a end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    return ("@%s#L%d-%d"):format(path, a, b)
  end
  return ("@%s#L%d"):format(path, vim.fn.line("."))
end

local function prompt(kind, text)
  local agent, err = find_agent(kind)
  if not agent then return vim.notify(err, vim.log.levels.WARN) end
  vim.system({ "herdr", "agent", "prompt", agent.pane_id, text }, {}, function(res)
    vim.schedule(function()
      if res.code == 0 then
        vim.notify(("sent to %s"):format(kind))
      else
        vim.notify(("%s: %s"):format(kind, vim.trim(res.stderr or "failed")), vim.log.levels.WARN)
      end
    end)
  end)
end

-- Prompt for an instruction, then send it with the code reference.
function M.send(kind)
  local ref = code_ref()
  vim.ui.input({ prompt = kind .. " › " .. ref .. " " }, function(msg)
    if msg == nil then return end
    prompt(kind, vim.trim(ref .. " " .. msg))
  end)
end

-- Send the whole file as an @path reference, with an instruction.
function M.send_file(kind)
  local ref = "@" .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.ui.input({ prompt = kind .. " › " .. ref .. " " }, function(msg)
    if msg == nil then return end
    prompt(kind, vim.trim(ref .. " " .. msg))
  end)
end

-- Send this buffer's diagnostics as a fix-it request.
function M.diagnostics(kind)
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local lines = {}
  for _, d in ipairs(vim.diagnostic.get(0)) do
    table.insert(lines, ("L%d: %s"):format(d.lnum + 1, d.message:gsub("\n", " ")))
  end
  if #lines == 0 then return vim.notify("no diagnostics in this buffer") end
  prompt(kind, ("Fix these diagnostics in @%s:\n%s"):format(path, table.concat(lines, "\n")))
end

return M
