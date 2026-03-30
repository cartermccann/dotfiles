{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
in
{
  stylix.targets.ghostty.enable = false;

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = ${c.base00}
    foreground = ${c.base05}

    palette = 0=${c.base01}
    palette = 1=${c.base08}
    palette = 2=${c.base0B}
    palette = 3=${c.base0A}
    palette = 4=${c.base0D}
    palette = 5=${c.base0E}
    palette = 6=${c.base0C}
    palette = 7=${c.base05}
    palette = 8=${c.base03}
    palette = 9=${c.base08}
    palette = 10=${c.base0B}
    palette = 11=${c.base0A}
    palette = 12=${c.base0D}
    palette = 13=${c.base0E}
    palette = 14=${c.base0C}
    palette = 15=${c.base07}

    cursor-color = ${c.base0D}
    cursor-text = ${c.base00}
    selection-foreground = ${c.base00}
    selection-background = ${c.base0D}

    background-opacity = 1.0
    background-blur = false
    cursor-style = bar
    cursor-style-blink = true
    adjust-cell-height = 2
    font-thicken = true
    bold-is-bright = false
    mouse-hide-while-typing = true
    clipboard-trim-trailing-spaces = true
    window-padding-x = 8
    window-padding-y = 8
    window-padding-balance = true
    gtk-titlebar = false
    window-decoration = false
    notify-on-command-finish = unfocused
    notify-on-command-finish-after = 10s
  '';
}
