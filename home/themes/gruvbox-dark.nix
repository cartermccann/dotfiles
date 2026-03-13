# Gruvbox Dark — warm retro browns, oranges, greens
# https://github.com/morhetz/gruvbox
{
  slug = "gruvbox-dark";
  name = "Gruvbox Dark";

  # Semantic colors
  primary = "#83a598"; # bright_blue
  secondary = "#b8bb26"; # bright_green
  tertiary = "#d3869b"; # bright_purple
  surface = "#282828"; # bg0
  surface_container = "#3c3836"; # bg1
  surface_container_high = "#504945"; # bg2
  on_surface = "#ebdbb2"; # fg1
  on_surface_variant = "#a89984"; # fg4
  error = "#fb4934"; # bright_red
  outline = "#665c54"; # bg3
  outline_variant = "#504945"; # bg2
  on_primary_container = "#83a598"; # bright_blue
  on_tertiary_container = "#d3869b"; # bright_purple

  # Tool-specific
  nvim_colorscheme = "gruvbox";
  nvim_plugin = "ellisonleao/gruvbox.nvim";
  delta_theme = "gruvbox-dark"; # built-in to bat/delta
  bat_theme = "gruvbox-dark";
}
