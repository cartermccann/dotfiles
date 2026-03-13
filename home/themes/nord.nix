# Nord — arctic blues and cool grays
# https://www.nordtheme.com/docs/colors-and-palettes
{
  slug = "nord";
  name = "Nord";

  # Semantic colors
  primary = "#88c0d0"; # nord8  — Frost
  secondary = "#a3be8c"; # nord14 — Aurora green
  tertiary = "#b48ead"; # nord15 — Aurora purple
  surface = "#2e3440"; # nord0  — Polar Night
  surface_container = "#3b4252"; # nord1
  surface_container_high = "#434c5e"; # nord2
  on_surface = "#eceff4"; # nord6  — Snow Storm
  on_surface_variant = "#d8dee9"; # nord4
  error = "#bf616a"; # nord11 — Aurora red
  outline = "#4c566a"; # nord3
  outline_variant = "#434c5e"; # nord2
  on_primary_container = "#88c0d0"; # nord8
  on_tertiary_container = "#b48ead"; # nord15

  # Tool-specific
  nvim_colorscheme = "nord";
  nvim_plugin = "shaunsingh/nord.nvim";
  delta_theme = "Nord"; # built-in to bat/delta
  bat_theme = "Nord";
}
