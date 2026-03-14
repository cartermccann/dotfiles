# Square — true black, grayscale, sharp edges
# Inspired by better-auth.com — hierarchy through whitespace, not color
{
  slug = "square";
  name = "Square";

  # Semantic colors — almost entirely grayscale
  primary = "#ffffff"; # pure white for active/focused elements
  secondary = "#a0a0a0"; # mid-gray for secondary emphasis
  tertiary = "#a0a0a0"; # same — keep it monotone
  surface = "#000000"; # true black
  surface_container = "#111111"; # barely-there panel elevation
  surface_container_high = "#1a1a1a"; # subtle card/surface lift
  on_surface = "#f0f0f0"; # near-white primary text
  on_surface_variant = "#707070"; # muted secondary text
  error = "#ff6b6b"; # soft red — only real color in the palette
  outline = "#222222"; # borders — barely visible
  outline_variant = "#181818"; # even subtler dividers
  on_primary_container = "#ffffff";
  on_tertiary_container = "#a0a0a0";

  # Tool-specific
  nvim_colorscheme = "lackluster";
  nvim_plugin = "slugbyte/lackluster.nvim";
  delta_theme = "ansi";
  bat_theme = "ansi";

  # Geometry & opacity
  border_radius = 0;
  background_opacity = 1.0;
}
