{
  config,
  lib,
  ...
}:
# fuzzel (launcher + every dmenu script) and swayosd (volume/brightness OSD).
let
  pal = import ../../lib/palette.nix;
  cssRgb = import ./css.nix lib;
  cfgHome = config.xdg.configHome;
in
{
  xdg.configFile."fuzzel/hypr.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=12
    prompt=>
    icon-theme=Papirus-Dark
    lines=10
    width=36
    horizontal-pad=20
    vertical-pad=16
    inner-pad=10
    layer=overlay

    [colors]
    background=${pal.raw.base00}cc
    text=${pal.raw.base05}ff
    prompt=${pal.raw.base04}ff
    placeholder=${pal.raw.base03}ff
    input=${pal.raw.base05}ff
    match=${pal.raw.base0D}ff
    selection=${pal.raw.base02}dd
    selection-text=${pal.raw.base07}ff
    selection-match=${pal.raw.base0C}ff
    border=${pal.raw.base0D}66

    [border]
    width=2
    radius=14
  '';

  # swayosd: glass OSD (server launched with --style above)
  xdg.configFile."swayosd/style.css".text = ''
    window {
      background: rgba(${cssRgb pal.base01}, 0.55);
      border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
      border-radius: 14px;
    }
    label {
      color: ${pal.base05};
      font-family: "JetBrainsMono Nerd Font", monospace;
    }
    progressbar trough {
      background: rgba(${cssRgb pal.base03}, 0.4);
    }
    progressbar progress {
      background: ${pal.base0D};
    }
    image {
      color: ${pal.base06};
    }
  '';

  # swaync: glassy notification center
}
