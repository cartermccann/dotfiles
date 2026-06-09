{ config, pkgs, ... }:
let
  # RICE-PLAN Tier 3.2 — ghostty is shared by both sessions, and the plan
  # accepts ferro leaking into niri (same call as the swaylock remap in 3.1).
  cc = import ../lib/ferro-palette.nix;
in
{
  stylix.targets.ghostty.enable = false;

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = ${cc.base00}
    foreground = ${cc.base05}

    palette = 0=${cc.base01}
    palette = 1=${cc.base08}
    palette = 2=${cc.base0B}
    palette = 3=${cc.base0A}
    palette = 4=${cc.base0D}
    palette = 5=${cc.base0E}
    palette = 6=${cc.base0C}
    palette = 7=${cc.base06}
    palette = 8=${cc.base03}
    palette = 9=${cc.base08}
    palette = 10=${cc.base0B}
    palette = 11=${cc.base0A}
    palette = 12=${cc.base0D}
    palette = 13=${cc.base0E}
    palette = 14=${cc.base0C}
    palette = 15=${cc.base07}

    cursor-color = ${cc.base0D}
    cursor-text = ${cc.base00}
    selection-foreground = ${cc.base07}
    selection-background = ${cc.base02}

    # Glass: ghostty owns background alpha so text stays fully opaque;
    # blur comes from the compositor (Hyprland decoration:blur / niri
    # background-effect). ghostty's own background-blur stays false — it's
    # a no-op on both (KDE-only on Linux, ghostty#4626). If hyprwm#9705
    # bites (full transparency on tab close), pin via window rule override.
    background-opacity = 0.78
    background-blur = false
    cursor-style = bar
    cursor-style-blink = true
    adjust-cell-height = 2
    font-thicken = true
    bold-is-bright = false
    mouse-hide-while-typing = true
    clipboard-trim-trailing-spaces = true
    window-padding-x = 14
    window-padding-y = 14
    window-padding-balance = true
    window-padding-color = extend
    minimum-contrast = 1.1
    unfocused-split-opacity = 0.85
    split-divider-color = ${cc.base02}
    gtk-titlebar = false
    window-decoration = false
    notify-on-command-finish = unfocused
    notify-on-command-finish-after = 10s
  '';
}
