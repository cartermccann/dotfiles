"""Every keybinding in one searchable list (Super+/), printed one per line for
fuzzel. Each source is read live, so the sheet can't drift from the config:

  desktop  ~/.config/hypr/hyprland.lua (the binds Nix generated)
  nvim     the running config's keymaps, via a headless nvim
  herdr    herdr's defaults overlaid with ~/.config/herdr/config.toml
  ly/bar   the greeter keys and waybar's click actions (fixed lists here)
"""

import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")


def row(section, keys, what):
    return f"{section:<8} {keys:<28} {what}"


def desktop(path):
    out = []
    for line in open(path):
        m = re.match(r'\s*hl\.bind\((.+?),\s*hl\.(dsp\.[\w.]+)\((.*?)\)\s*(?:,\s*\{[^}]*\})?\)\s*(?:--\s*(.*))?$', line)
        if not m or " .. i" in m.group(1) or "key" in m.group(1):
            continue
        key = re.sub(r'mod\s*\.\.\s*"', "Super", m.group(1)).strip('"').replace(" + ", "+").replace(" ", "")
        key = "+".join(p.capitalize() if p.isupper() and len(p) > 1 else p for p in key.split("+"))
        arg = m.group(3).strip("[]\"' ")
        what = m.group(4) or (arg[:64] if m.group(2) == "dsp.exec_cmd" else m.group(2)[4:])
        out.append(row("desktop", key, what.strip()))
    return out


NVIM_DUMP = r"""
local rows = {}
for _, mode in ipairs({ "n", "x", "i", "t" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if m.desc and m.desc ~= "" and not m.lhs:find("<Plug>") then
      rows[#rows + 1] = { mode = mode, lhs = m.lhs, desc = m.desc }
    end
  end
end
io.stdout:write(vim.json.encode(rows))
"""

# Buffer-local maps that only exist once a language server attaches.
LSP = [
    ("gd", "Goto definition"), ("gr", "References"), ("gI", "Goto implementation"),
    ("gy", "Goto type definition"), ("gD", "Goto declaration"), ("K", "Hover docs"),
    ("<leader>ca", "Code action"), ("<leader>cr", "Rename"), ("<leader>ss", "Symbols"),
    ("<leader>sS", "Workspace symbols"), ("<leader>cl", "LSP info"),
]


def nvim():
    try:
        res = subprocess.run(
            ["nvim", "--headless", "+lua " + NVIM_DUMP.replace("\n", " "), "+qa"],
            capture_output=True, text=True, timeout=10,
        )
        maps = json.loads(res.stdout or res.stderr or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return [row("nvim", "?", "couldn't read the nvim config")]
    out = []
    seen = set()
    for m in sorted(maps, key=lambda m: m["lhs"]):
        lhs = m["lhs"]
        if lhs.startswith(" "):
            lhs = "<leader>" + lhs[1:]
        tag = {"n": "", "x": " (visual)", "i": " (insert)", "t": " (terminal)"}[m["mode"]]
        if (lhs, m["desc"]) in seen:
            continue
        seen.add((lhs, m["desc"]))
        out.append(row("nvim", lhs, m["desc"] + tag))
    out += [row("nvim", k, d + " (LSP)") for k, d in LSP]
    return out


def herdr():
    try:
        defaults = subprocess.run(["herdr", "--default-config"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    keys, in_keys = {}, False
    for line in defaults.splitlines():
        if line.startswith("["):
            in_keys = line.strip() == "[keys]"
        m = in_keys and re.match(r'#\s*(\w+)\s*=\s*"([^"]*)"', line)
        if m:
            keys[m.group(1)] = m.group(2)
    user = os.path.join(HOME, ".config/herdr/config.toml")
    if os.path.exists(user):
        in_keys = False
        for line in open(user):
            if line.startswith("["):
                in_keys = line.strip() == "[keys]"
            m = in_keys and re.match(r'(\w+)\s*=\s*"([^"]*)"', line)
            if m:
                keys[m.group(1)] = m.group(2)
    prefix = keys.pop("prefix", "ctrl+b")
    out = [row("herdr", prefix, "prefix")]
    for action, binding in keys.items():
        if binding:
            out.append(row("herdr", binding.replace("prefix+", prefix + " "), action.replace("_", " ")))
    return out


LY = [("F1", "Shut down"), ("F2", "Reboot"), ("F3", "Sleep"), ("F7", "Show password")]

BAR = [
    ("click modes ⋯", "Show inactive modes; click one to toggle it"),
    ("click clock", "Toggle ISO/week format"),
    ("middle-click clock", "Step through timezones (UTC)"),
    ("click AGENTS", "Agent switcher"),
    ("click UPD", "Updates menu"),
    ("click media", "Play/pause (middle: next, scroll: prev/next)"),
    ("click TS", "Tailscale menu (right-click: up/down)"),
    ("click MIC", "Mute mic (scroll: input volume)"),
    ("click VOL", "Output picker (right: mute, middle: pavucontrol)"),
    ("click bell", "Notification center (right: do not disturb)"),
]


def main():
    lines = desktop(sys.argv[1]) + nvim() + herdr()
    lines += [row("ly", k, d) for k, d in LY] + [row("bar", k, d) for k, d in BAR]
    print("\n".join(lines))


if __name__ == "__main__":
    main()
