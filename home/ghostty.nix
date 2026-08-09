{ config, pkgs, ... }:
let
  # ghostty is shared by both sessions, so the hyprland palette leaks into niri
  # by design — a themed terminal beats a per-session config split.
  pal = import ../lib/palette.nix;
in
{
  stylix.targets.ghostty.enable = false;

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = ${pal.base00}
    foreground = ${pal.base05}

    palette = 0=${pal.base01}
    palette = 1=${pal.base08}
    palette = 2=${pal.base0B}
    palette = 3=${pal.base0A}
    palette = 4=${pal.base0D}
    palette = 5=${pal.base0E}
    palette = 6=${pal.base0C}
    palette = 7=${pal.base06}
    palette = 8=${pal.base03}
    palette = 9=${pal.base08}
    palette = 10=${pal.base0B}
    palette = 11=${pal.base0A}
    palette = 12=${pal.base0D}
    palette = 13=${pal.base0E}
    palette = 14=${pal.base0C}
    palette = 15=${pal.base07}

    cursor-color = ${pal.base0D}
    cursor-text = ${pal.base00}
    selection-foreground = ${pal.base07}
    selection-background = ${pal.base02}

    # Glass: ghostty owns background alpha so text stays fully opaque; blur
    # comes from the compositor, which in practice means Hyprland's
    # decoration:blur only. Mainline niri has no blur of any kind — this
    # comment used to claim a `background-effect` node, and believing it is
    # what left an unparseable node in the niri config that silently dropped
    # that whole session to compiled-in defaults. Under niri this stays
    # transparent over the wallpaper, unblurred. ghostty's own
    # background-blur stays false regardless — it's
    # a no-op on both (KDE-only on Linux, ghostty#4626). If hyprwm#9705
    # bites (full transparency on tab close), pin via window rule override.
    # 0.68 = heavy glass; minimum-contrast below keeps glyphs legible over it.
    background-opacity = 0.68
    background-blur = false
    cursor-style = bar
    cursor-style-blink = true

    # Smooth cursor (ghostty 1.2+ cursor uniforms; relative path = next to
    # this config file). Three vendored options — exactly one active:
    #   cursor_warp.glsl  — Neovide-like: cursor stretches into a wedge and
    #                       snaps back (per-corner easing). Current pick.
    #   cursor_tail.glsl  — kitty-like comet trail, capped length.
    #   cursor_smear.glsl — original ribbon smear, quietest.
    # Switch cursor-style to block for a bolder trail — bar gives a thin
    # light-streak, which is the quieter read.
    custom-shader = shaders/cursor_warp.glsl
    # `always`, not `true`: with a bar cursor, unfocus swaps to a hollow block
    # — trail shaders trigger on that change and freeze mid-frame unless the
    # animation keeps ticking (sahaj-b/ghostty-cursor-shaders README).
    custom-shader-animation = always
    adjust-cell-height = 2
    font-thicken = true
    bold-is-bright = false
    mouse-hide-while-typing = true
    clipboard-trim-trailing-spaces = true
    window-padding-x = 14
    window-padding-y = 14
    window-padding-balance = true
    window-padding-color = extend
    minimum-contrast = 1.2
    unfocused-split-opacity = 0.85
    split-divider-color = ${pal.base02}
    gtk-titlebar = false
    window-decoration = false
    notify-on-command-finish = unfocused
    notify-on-command-finish-after = 10s
  '';

  xdg.configFile."ghostty/shaders/cursor_smear.glsl".source = ./ghostty-shaders/cursor_smear.glsl;
  xdg.configFile."ghostty/shaders/cursor_warp.glsl".source = ./ghostty-shaders/cursor_warp.glsl;
  xdg.configFile."ghostty/shaders/cursor_tail.glsl".source = ./ghostty-shaders/cursor_tail.glsl;
}
