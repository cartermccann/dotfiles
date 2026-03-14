{ pkgs, ... }:
let
  themes = {
    square = import ./themes/square.nix;
    nord = import ./themes/nord.nix;
    tokyo-night = import ./themes/tokyo-night.nix;
    kanagawa = import ./themes/kanagawa.nix;
    gruvbox-dark = import ./themes/gruvbox-dark.nix;
    rose-pine = import ./themes/rose-pine.nix;
    catppuccin-mocha = import ./themes/catppuccin-mocha.nix;
  };

  # Change this to switch spotify-player's theme at rebuild time
  activeTheme = themes.catppuccin-mocha;

  mkTheme = name: t: {
    inherit name;
    palette = {
      background = t.surface;
      foreground = t.on_surface;
      black = t.surface;
      red = t.error;
      green = t.tertiary;
      yellow = t.secondary;
      blue = t.primary;
      magenta = t.tertiary;
      cyan = t.secondary;
      white = t.on_surface;
      bright_black = t.outline;
      bright_red = t.error;
      bright_green = t.tertiary;
      bright_yellow = t.secondary;
      bright_blue = t.primary;
      bright_magenta = t.on_tertiary_container;
      bright_cyan = t.on_primary_container;
      bright_white = t.on_surface;
    };
    component_style = {
      block_title = { fg = "Blue"; modifiers = ["Bold"]; };
      border = { fg = "BrightBlack"; };
      playback_track = { fg = "White"; modifiers = ["Bold"]; };
      playback_artists = { fg = "BrightBlack"; };
      playback_album = { fg = "BrightBlack"; };
      playback_progress_bar = { fg = "Blue"; };
      current_playing = { fg = "Blue"; modifiers = ["Bold"]; };
      page_desc = { fg = "BrightBlack"; };
      table_header = { fg = "BrightBlack"; modifiers = ["Bold"]; };
      selection = { fg = "Blue"; modifiers = ["Bold"]; };
    };
  };
in
{
  home.packages = [ pkgs.spotify ];

  programs.spotify-player = {
    enable = true;
    settings = {
      theme = activeTheme.slug;
      playback_window_position = "Top";
      copy_command = {
        command = "${pkgs.wl-clipboard}/bin/wl-copy";
        args = [];
      };
      device = {
        audio_cache = false;
        normalization = false;
      };
    };
    themes = builtins.map (name: mkTheme name themes.${name}) (builtins.attrNames themes);
  };
}
