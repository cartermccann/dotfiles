{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
in
{
  home.packages = [ pkgs.spotify ];

  programs.spotify-player = {
    enable = true;
    settings = {
      theme = "stylix";
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
    themes = [
      {
        name = "stylix";
        palette = {
          background = c.base00;
          foreground = c.base05;
          black = c.base01;
          red = c.base08;
          green = c.base0B;
          yellow = c.base0A;
          blue = c.base0D;
          magenta = c.base0E;
          cyan = c.base0C;
          white = c.base05;
          bright_black = c.base03;
          bright_red = c.base08;
          bright_green = c.base0B;
          bright_yellow = c.base0A;
          bright_blue = c.base0D;
          bright_magenta = c.base0E;
          bright_cyan = c.base0C;
          bright_white = c.base07;
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
      }
    ];
  };
}
