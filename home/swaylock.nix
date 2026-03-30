{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
in
{
  stylix.targets.swaylock.enable = false;

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # Effects
      screenshots = true;
      clock = true;
      indicator = true;
      indicator-radius = 120;
      indicator-thickness = 8;
      effect-blur = "12x5";
      effect-vignette = "0.5:0.5";
      grace = 3;
      fade-in = 0.2;

      # Colors (Catppuccin via Stylix)
      inside-color = "${c.base00}cc";
      inside-clear-color = "${c.base00}cc";
      inside-caps-lock-color = "${c.base00}cc";
      inside-ver-color = "${c.base0D}cc";
      inside-wrong-color = "${c.base08}cc";

      ring-color = "${c.base02}";
      ring-clear-color = "${c.base0A}";
      ring-caps-lock-color = "${c.base09}";
      ring-ver-color = "${c.base0D}";
      ring-wrong-color = "${c.base08}";

      key-hl-color = "${c.base0D}";
      bs-hl-color = "${c.base08}";
      separator-color = "00000000";

      text-color = "${c.base05}";
      text-clear-color = "${c.base05}";
      text-caps-lock-color = "${c.base05}";
      text-ver-color = "${c.base00}";
      text-wrong-color = "${c.base00}";

      # Layout
      font = "JetBrainsMono Nerd Font";
      font-size = 24;
      timestr = "%H:%M";
      datestr = "%A, %B %d";
    };
  };
}
