{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold.family = "JetBrainsMono Nerd Font";
        italic.family = "JetBrainsMono Nerd Font";
        size = 14;
      };
      window = {
        opacity = 0.92;
        padding = { x = 8; y = 8; };
      };
      cursor = {
        style = {
          shape = "Beam";
          blinking = "On";
        };
      };
      colors = {
        primary = {
          background = "#2E3440";
          foreground = "#D8DEE9";
        };
        normal = {
          black = "#3B4252";
          red = "#BF616A";
          green = "#A3BE8C";
          yellow = "#EBCB8B";
          blue = "#81A1C1";
          magenta = "#B48EAD";
          cyan = "#88C0D0";
          white = "#E5E9F0";
        };
        bright = {
          black = "#4C566A";
          red = "#BF616A";
          green = "#A3BE8C";
          yellow = "#EBCB8B";
          blue = "#81A1C1";
          magenta = "#B48EAD";
          cyan = "#8FBCBB";
          white = "#ECEFF4";
        };
      };
    };
  };
}
