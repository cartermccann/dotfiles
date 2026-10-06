"""Every keybinding in one searchable list (Super+/), printed one per line for
fuzzel. Each source is read live, so the sheet can't drift from the config:

  desktop  `hyprctl binds -j`; every bind in compositor.nix carries a description
  nvim     the config's keymaps, via a headless nvim
  tmux     `list-keys -N` against the tmux.conf on disk; custom binds carry notes
  herdr    herdr's defaults overlaid with ~/.config/herdr/config.toml
  ly/bar   the greeter keys and waybar's click actions (fixed lists here)
"""

import json
import os
import re
import subprocess
import tomllib

HOME = os.path.expanduser("~")


def run(cmd, timeout=10):
    """stdout of cmd, or None if it couldn't run or failed."""
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return res.stdout if res.returncode == 0 else None


# hyprland modmask bits, in the order they're written
MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
KEYS = {
    "RETURN": "Enter", "SPACE": "Space", "ESCAPE": "Esc", "TAB": "Tab",
    "slash": "/", "grave": "`", "minus": "-", "equal": "=", "comma": ",",
    "backslash": "\\", "left": "←", "right": "→", "up": "↑", "down": "↓",
    "mouse:272": "left drag", "mouse:273": "right drag",
}


def chord(modmask, key):
    key = KEYS.get(key, key.removeprefix("XF86"))
    return "+".join([name for bit, name in MODS if modmask & bit] + [key])


def desktop():
    out = run(["hyprctl", "binds", "-j"])
    if out is None:
        return [("desktop", "?", "couldn't reach Hyprland")]
    binds = [b for b in json.loads(out) if not b["catch_all"]]
    # a submap's rows are shown behind the root bind that enters it, found by
    # its description naming the submap ("tmux mode (prefix)")
    prefix = {}
    for b in binds:
        if not b["submap"]:
            for name in {x["submap"] for x in binds if x["submap"]}:
                if b["description"].lower().startswith(name):
                    prefix[name] = chord(b["modmask"], b["key"])
    rows, runs = [], {}
    for b in binds:
        keys = chord(b["modmask"], b["key"])
        if b["submap"]:
            keys = f"{prefix.get(b['submap'], b['submap'])} › {keys}"
        what = b["description"] or "(no description)"
        # Super+1..0 and friends: one row per run of digit keys
        m = re.fullmatch(r"(.*?)(\d+)", what)
        if b["key"].isdigit() and m:
            group = (b["submap"], b["modmask"], m.group(1))
            if group not in runs:
                runs[group] = []
                rows.append(("desktop", runs[group], m.group(1)))
            runs[group].append((keys, int(m.group(2))))
            continue
        rows.append(("desktop", keys, what))
    out = []
    for section, keys, what in rows:
        if isinstance(keys, list):
            keys.sort(key=lambda k: k[1])
            (first, lo), (last, hi) = keys[0], keys[-1]
            keys, what = f"{first}…{last[-1]}", f"{what}{lo}–{hi}"
        out.append((section, keys, what))
    return out


NVIM_DUMP = r"""
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
local rows = {}
for _, mode in ipairs({ "n", "x", "i", "t" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    if m.desc and m.desc ~= "" and m.desc ~= "which_key_ignore" and not m.lhs:find("<Plug>") then
      rows[#rows + 1] = { mode = mode, lhs = m.lhs, desc = m.desc }
    end
  end
end
io.stdout:write(vim.json.encode(rows))
"""

# Buffer-local maps that only exist once something attaches, so a headless
# dump can't see them. Sources: config/nvim/lua/lsp.lua (LspAttach) and the
# gitsigns on_attach in config/nvim/lua/plugins/editor.lua.
ATTACHED = [
    ("LSP", [
        ("gd", "Goto definition"), ("gr", "References"), ("gI", "Goto implementation"),
        ("gy", "Goto type definition"), ("gD", "Goto declaration"), ("K", "Hover docs"),
        ("<leader>ca", "Code action"), ("<leader>cr", "Rename"), ("<leader>ss", "Symbols"),
        ("<leader>sS", "Workspace symbols"), ("<leader>cl", "LSP info"),
    ]),
    ("git", [
        ("]h", "Next hunk"), ("[h", "Prev hunk"), ("<leader>ghs", "Stage hunk"),
        ("<leader>ghr", "Reset hunk"), ("<leader>ghp", "Preview hunk"),
        ("<leader>ghb", "Blame line"), ("<leader>ghB", "Blame buffer"),
        ("<leader>ghS", "Stage buffer"), ("<leader>ghR", "Reset buffer"),
        ("<leader>ghu", "Undo stage hunk"), ("<leader>ghd", "Diff this"),
        ("<leader>ghD", "Diff this ~"),
    ]),
]


def nvim():
    out = run(["nvim", "--headless", "-i", "NONE", "+lua " + NVIM_DUMP.replace("\n", " "), "+qa"])
    try:
        maps = json.loads(out)
    except (TypeError, ValueError):
        return [("nvim", "?", "couldn't read the nvim config")]
    rows, seen = [], set()
    for m in sorted(maps, key=lambda m: m["lhs"]):
        lhs = m["lhs"]
        if len(lhs) > 1 and lhs.startswith(" "):
            lhs = "<leader>" + lhs[1:]
        lhs = lhs.replace(" ", "<space>")
        if (lhs, m["desc"]) in seen:
            continue
        seen.add((lhs, m["desc"]))
        tag = {"n": "", "x": " (visual)", "i": " (insert)", "t": " (terminal)"}[m["mode"]]
        rows.append(("nvim", lhs, m["desc"] + tag))
    for source, maps in ATTACHED:
        rows += [("nvim", k, f"{d} ({source})") for k, d in maps]
    return rows


def tmux():
    # A throwaway server on its own socket reads the tmux.conf on disk, so the
    # sheet matches the config even if the running server predates a rebuild.
    # It has no sessions, so it exits as soon as list-keys returns.
    conf = os.path.join(HOME, ".config/tmux/tmux.conf")
    out = run(["tmux", "-L", "ouranos-keys", "-f", conf, "start-server", ";",
               "show-options", "-gv", "prefix", ";", "list-keys", "-N"])
    if out is None:
        return [("tmux", "?", "couldn't read the tmux config")]
    prefix, *lines = out.splitlines()
    rows = []
    for line in lines:
        # "C-a c   New window", or "M-Up   Previous session" for the root table;
        # the key column is padded, sometimes down to a single space
        words = line.split()
        n = 2 if words[0] == prefix else 1
        if len(words) > n:
            rows.append(("tmux", " ".join(words[:n]), " ".join(words[n:])))
    return rows


def herdr():
    defaults = run(["herdr", "--default-config"], timeout=5)
    if defaults is None:
        return []
    # the defaults ship commented out; read [keys] up to the next section,
    # commented or not ("# [[keys.command]]" is an example, not a binding)
    keys, section = {}, None
    for line in defaults.splitlines():
        header = re.match(r"#?\s*(\[+[\w.]+\]+)", line)
        if header:
            section = header.group(1)
            continue
        m = section == "[keys]" and re.match(r'#\s*(\w+)\s*=\s*"([^"]*)"\s*(#.*)?$', line)
        if m:
            keys[m.group(1)] = m.group(2)
    commands = []
    try:
        with open(os.path.join(HOME, ".config/herdr/config.toml"), "rb") as f:
            user = tomllib.load(f).get("keys", {})
    except (OSError, tomllib.TOMLDecodeError):
        user = {}
    for action, binding in user.items():
        if isinstance(binding, str):
            keys[action] = binding
        elif action == "command":
            commands = [c for c in binding if c.get("key") and c.get("command")]
    prefix = keys.pop("prefix", "ctrl+b")
    rows = [("herdr", prefix, "prefix")]

    def show(binding):
        return binding.replace("prefix+", prefix + " ")

    for action, binding in keys.items():
        if binding:
            what = action.replace("_", " ")
            if action.startswith("navigate_"):
                what = what.removeprefix("navigate ") + " (navigate mode)"
            rows.append(("herdr", show(binding), what))
    rows += [("herdr", show(c["key"]), c["command"]) for c in commands]
    return rows


LY = [("F1", "Shut down"), ("F2", "Reboot"), ("F3", "Sleep"), ("F7", "Show password")]

# waybar's on-click actions, from home/hyprland/waybar.nix
BAR = [
    ("click workspace", "Switch to it"),
    ("click modes ⋯", "Show inactive modes; click one to toggle it"),
    ("click clock", "Toggle ISO/week format"),
    ("middle-click clock", "Step through timezones (UTC)"),
    ("click AGENTS", "Agent switcher"),
    ("click UPD", "Updates menu"),
    ("click media", "Play/pause (middle or right: next, scroll: next/prev)"),
    ("click GPU/CPU/MEM", "btop"),
    ("click TS", "Tailscale menu (right-click: up/down)"),
    ("click network", "nmtui"),
    ("click bluetooth", "bluetui"),
    ("click MIC", "Mute mic (middle: input devices, scroll: input volume)"),
    ("click VOL", "Output picker (right: mute, middle: pavucontrol)"),
    ("click bell", "Notification center (right: do not disturb)"),
    ("click ⏻", "Power menu"),
]


def main():
    rows = desktop() + nvim() + tmux() + herdr()
    rows += [("ly", k, d) for k, d in LY] + [("bar", k, d) for k, d in BAR]
    width = min(32, max(len(k) for _, k, _ in rows))
    print("\n".join(f"{s:<8} {k:<{width}} {w}" for s, k, w in rows))


if __name__ == "__main__":
    main()
