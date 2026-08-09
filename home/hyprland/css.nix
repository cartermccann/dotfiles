# "#1b1917" -> "27, 25, 23" for CSS rgba(). Kept here rather than duplicated in
# each stylesheet module: waybar, swaync and swayosd all need it.
#
# Usage:  cssRgb = import ./css.nix lib;
lib: hex:
let
  h = lib.removePrefix "#" hex;
in
lib.concatStringsSep ", " (
  map (i: toString (lib.fromHexString (builtins.substring i 2 h))) [
    0
    2
    4
  ]
)
