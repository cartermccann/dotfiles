# Square — true black, mostly monochrome, sharp edges
# Inspired by better-auth.com + neo-brutalist elements
# Blue (#0055ff) is reserved for Neovim only (cursor line, search)
{
  slug = "square";
  name = "Square";

  # Semantic colors — black + white, no color
  primary = "#ffffff"; # white for active/focused elements
  secondary = "#e0e0e0"; # light grey
  tertiary = "#e0e0e0"; # match secondary
  surface = "#000000"; # true black
  surface_container = "#000000"; # true black — no grey panels
  surface_container_high = "#0a0a0a"; # barely-there elevation
  on_surface = "#f0f0f0"; # near-white primary text
  on_surface_variant = "#505050"; # dark muted text
  error = "#ff3333"; # bold brutalist red
  outline = "#333333"; # visible borders (neo-brutalist)
  outline_variant = "#1a1a1a"; # subtle dividers
  on_primary_container = "#ffffff";
  on_tertiary_container = "#e0e0e0";

  # Tool-specific
  nvim_colorscheme = "square";
  nvim_plugin = "slugbyte/lackluster.nvim"; # keep as fallback
  delta_theme = "ansi";
  bat_theme = "ansi";

  # Geometry & opacity
  border_radius = 0;
  background_opacity = 1.0;
}
