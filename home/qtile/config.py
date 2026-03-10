import os
import subprocess
from libqtile import bar, layout, qtile, widget, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

mod = "mod4"
terminal = "alacritty"

# ── Nord Palette ──────────────────────────────────────────────
nord0 = "#2E3440"   # Polar Night
nord1 = "#3B4252"
nord2 = "#434C5E"
nord3 = "#4C566A"
nord4 = "#D8DEE9"   # Snow Storm
nord5 = "#E5E9F0"
nord6 = "#ECEFF4"
nord7 = "#8FBCBB"   # Frost
nord8 = "#88C0D0"
nord9 = "#81A1C1"
nord10 = "#5E81AC"
nord11 = "#BF616A"  # Aurora
nord12 = "#D08770"
nord13 = "#EBCB8B"
nord14 = "#A3BE8C"
nord15 = "#B48EAD"

# ── Keybindings ───────────────────────────────────────────────
keys = [
    # Window focus
    Key([mod], "j", lazy.layout.down(), desc="Focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Focus up"),
    Key([mod], "h", lazy.layout.shrink_main(), desc="Shrink main"),
    Key([mod], "l", lazy.layout.grow_main(), desc="Grow main"),

    # Window movement
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Shuffle down"),
    Key([mod, "shift"], "Up", lazy.layout.shuffle_up(), desc="Shuffle up"),
    Key([mod, "shift"], "k", lazy.spawn(os.path.expanduser("~/.config/qtile/show-keys.sh")), desc="Show keybindings"),

    # Layout toggles
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Fullscreen"),
    Key([mod], "space", lazy.window.toggle_floating(), desc="Toggle floating"),
    Key([mod], "Tab", lazy.next_layout(), desc="Next layout"),

    # Apps
    Key([mod], "Return", lazy.spawn(terminal), desc="Terminal"),
    Key([mod], "d", lazy.spawn("rofi -show drun -show-icons"), desc="Rofi"),
    Key([mod], "b", lazy.spawn("firefox"), desc="Firefox"),
    Key([mod], "Print", lazy.spawn("flameshot gui"), desc="Screenshot"),

    # Window management
    Key([mod], "q", lazy.window.kill(), desc="Kill window"),
    Key([mod, "shift"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "shift"], "q", lazy.shutdown(), desc="Logout"),

    # Volume
    Key([], "XF86AudioRaiseVolume", lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")),
    Key([], "XF86AudioMute", lazy.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle")),

    # Brightness
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +10%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),
]

# ── Workspaces ────────────────────────────────────────────────
groups = [
    Group("1", label="TERM"),
    Group("2", label="WEB"),
    Group("3", label="CODE"),
    Group("4", label="DOCK"),
    Group("5", label="CHAT"),
    Group("6", label="SYS"),
]

for g in groups:
    keys.extend([
        Key([mod], g.name, lazy.group[g.name].toscreen(), desc=f"Switch to {g.label}"),
        Key([mod, "shift"], g.name, lazy.window.togroup(g.name), desc=f"Move to {g.label}"),
    ])

# ── Layouts ───────────────────────────────────────────────────
layout_theme = {
    "border_width": 2,
    "border_focus": nord9,
    "border_normal": nord1,
    "margin": 4,
}

layouts = [
    layout.MonadTall(**layout_theme),
    layout.Max(**layout_theme),
    layout.Floating(**layout_theme),
]

# ── Bar Widgets ───────────────────────────────────────────────
widget_defaults = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=13,
    padding=6,
    foreground=nord4,
    background=nord0,
)
extension_defaults = widget_defaults.copy()

def sep():
    return widget.Sep(linewidth=0, padding=8, background=nord0)

screens = [
    Screen(
        wallpaper=os.path.expanduser("~/wallpaper.png"),
        wallpaper_mode="fill",
        top=bar.Bar(
            [
                widget.GroupBox(
                    active=nord4,
                    inactive=nord3,
                    highlight_method="line",
                    highlight_color=[nord0, nord0],
                    this_current_screen_border=nord9,
                    urgent_border=nord11,
                    rounded=False,
                    padding=4,
                ),
                sep(),
                widget.WindowName(
                    foreground=nord8,
                    max_chars=50,
                    format="{name}",
                ),
                widget.Spacer(),
                widget.CPU(
                    format="  {load_percent}%",
                    foreground=nord14,
                    update_interval=2,
                ),
                sep(),
                widget.Memory(
                    format="  {MemUsed:.0f}{mm}",
                    foreground=nord13,
                    update_interval=2,
                ),
                sep(),
                widget.Net(
                    format="  {down:.0f}{down_suffix}",
                    foreground=nord8,
                    update_interval=2,
                ),
                sep(),
                widget.Volume(
                    fmt="  {}",
                    foreground=nord15,
                ),
                sep(),
                widget.Clock(
                    format="  %a %b %d  %I:%M %p",
                    foreground=nord9,
                ),
                sep(),
                widget.Systray(
                    padding=4,
                ),
                widget.Sep(linewidth=0, padding=4),
            ],
            size=28,
            background=nord0,
            opacity=0.92,
            margin=[6, 6, 0, 6],  # top, right, bottom, left — outer gap at top
        ),
    ),
]

# ── Mouse / Floating ─────────────────────────────────────────
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

floating_layout = layout.Floating(
    border_focus=nord9,
    border_normal=nord1,
    border_width=2,
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="pavucontrol"),
        Match(wm_class="flameshot"),
    ],
)

# ── Autostart ─────────────────────────────────────────────────
@hook.subscribe.startup_once
def autostart():
    script = os.path.expanduser("~/.config/qtile/autostart.sh")
    subprocess.Popen([script])

# ── Settings ──────────────────────────────────────────────────
dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
floats_kept_above = True
cursor_warp = False
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True
wl_input_rules = None
wmname = "Qtile"
