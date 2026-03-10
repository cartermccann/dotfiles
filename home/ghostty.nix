{ config, pkgs, ... }:

{
  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = #2E3440
    foreground = #D8DEE9

    palette = 0=#3B4252
    palette = 1=#BF616A
    palette = 2=#A3BE8C
    palette = 3=#EBCB8B
    palette = 4=#81A1C1
    palette = 5=#B48EAD
    palette = 6=#88C0D0
    palette = 7=#E5E9F0
    palette = 8=#4C566A
    palette = 9=#BF616A
    palette = 10=#A3BE8C
    palette = 11=#EBCB8B
    palette = 12=#81A1C1
    palette = 13=#B48EAD
    palette = 14=#8FBCBB
    palette = 15=#ECEFF4

    background-opacity = 0.92
    cursor-style = bar
    cursor-style-blink = true
    window-padding-x = 8
    window-padding-y = 8
    gtk-titlebar = false
    window-decoration = false
  '';
}
