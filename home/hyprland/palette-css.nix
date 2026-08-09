# Emits the Ouranos palette as GTK `@define-color` declarations.
#
# This is what lets the stylesheets under config/hyprland/ be plain, static
# .css files: no Nix string interpolation, no `@placeholder@` substitution
# pass, and real syntax highlighting in an editor. Each consumer writes this
# next to its stylesheet as `_ouranos.css` and pulls it in with
# `@import url("_ouranos.css");` — GTK resolves the URL relative to the
# importing file, so the two always travel together.
#
# Solids use `@base05`. Translucency uses `alpha(@base01, 0.45)` rather than
# `rgba(15, 18, 24, 0.45)`: GTK's alpha() *multiplies* the colour's existing
# alpha, and every slot defined here is fully opaque, so alpha(@x, a) is
# exactly the rgba() form it replaces — verified against every translucent
# colour in both stylesheets via GTK's computed style.
#
# ./css.nix (the hex -> "r, g, b" helper) is still used by lock.nix and
# menus.nix, whose stylesheets are small enough to stay inline; it is no longer
# needed by waybar or swaync.
#
# Every hex-valued attribute is exported, so the semantic aliases (@accent,
# @surface, @border, @text, ...) are available alongside the base16 slots.
#
# Usage:  ouranosCss = import ./palette-css.nix lib pal;
lib: pal:
let
  isHex = v: builtins.isString v && builtins.match "#[0-9a-fA-F]{6}" v != null;
  colors = lib.filterAttrs (_: isHex) pal;
in
lib.concatStrings (lib.mapAttrsToList (name: hex: "@define-color ${name} ${hex};\n") colors)
