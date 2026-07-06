# Hyprland session palette — Base16 mapping.
# Warm espresso/cream monochrome + azure accent + retro green-phosphor motif.
# Consumed only by the Hyprland sessions' components (hyprland.lua, its
# waybar, fuzzel, swaync, hyprlock); the rest of the system keeps its global
# Stylix palette. Import with: let pal = import ../lib/palette.nix;
rec {
  # Base16 slots, with leading "#" (for GTK CSS / configs that want hex)
  base00 = "#141210"; # bg            (espresso black)
  base01 = "#1b1917"; # surface       (raised bg / status)
  base02 = "#211e1a"; # selection     (raised)
  base03 = "#6b655d"; # muted         (comments / disabled)
  base04 = "#8a847c"; # dark fg       (taupe)
  base05 = "#e8e4df"; # default fg    (warm cream)
  base06 = "#c5bfb5"; # light fg
  base07 = "#f2efe9"; # lightest      (warm near-white)
  base08 = "#e06c5e"; # red           (derived warm — ANSI only)
  base09 = "#d99a5c"; # orange        (derived — ANSI only)
  base0A = "#cbb46a"; # yellow        (derived — ANSI only)
  base0B = "#3ddc84"; # green         (brand phosphor-adjacent)
  base0C = "#72b8ff"; # cyan / azure-bright (oklch 0.72/235)
  base0D = "#7b7bff"; # blue          → PRIMARY azure accent (focus/active)
  base0E = "#a98bff"; # magenta       (periwinkle)
  base0F = "#2d8a4e"; # brown slot    → brand deep green

  # Same slots without "#" — for fuzzel (RRGGBBAA) and Hyprland rgba(...)
  raw = {
    base00 = "141210";
    base01 = "1b1917";
    base02 = "211e1a";
    base03 = "6b655d";
    base04 = "8a847c";
    base05 = "e8e4df";
    base06 = "c5bfb5";
    base07 = "f2efe9";
    base08 = "e06c5e";
    base09 = "d99a5c";
    base0A = "cbb46a";
    base0B = "3ddc84";
    base0C = "72b8ff";
    base0D = "7b7bff";
    base0E = "a98bff";
    base0F = "2d8a4e";
  };

  # Semantic aliases
  bg = base00;
  surface = base01;
  raised = base02;
  text = base05;
  textDim = "#a39d94";
  accent = base0D; # azure
  accentBright = base0C;
  phosphorBg = "#0a1a0a";
  phosphorText = "#33ff33";
}
