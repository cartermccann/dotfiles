{
  lib,
  ...
}:
# swaync: notification daemon config and stylesheet.
let
  pal = import ../../lib/palette.nix;
  cssRgb = import ./css.nix lib;
in
{
  xdg.configFile."swaync/config.json".text = builtins.toJSON {
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    control-center-layer = "top";
    control-center-width = 380;
    control-center-margin-top = 10;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    notification-window-width = 380;
    timeout = 8;
    timeout-low = 5;
    timeout-critical = 0;
    fit-to-screen = true;
    widgets = [
      "title"
      "dnd"
      "notifications"
    ];
    widget-config = {
      title = {
        text = "notifications";
        clear-all-button = true;
        button-text = "clear";
      };
      dnd = {
        text = "do not disturb";
      };
    };
  };

  xdg.configFile."swaync/style.css".text = ''
    /* Explicit type scale — swaync otherwise inherits the (oversized) GTK default. */
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 12px;
    }
    .control-center {
      background: rgba(${cssRgb pal.base00}, 0.60);
      color: ${pal.base05};
      border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
      border-radius: 16px;
      margin: 8px;
      padding: 12px;
    }
    .notification-row .notification-background .notification {
      background: rgba(${cssRgb pal.base01}, 0.65);
      color: ${pal.base05};
      border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
      border-radius: 14px;
      margin: 6px 4px;
      padding: 4px;
    }
    .notification-row .notification-background .notification.critical {
      border-color: ${pal.base08};
    }
    .notification .summary {
      font-size: 13px;
      font-weight: 600;
      color: ${pal.base05};
    }
    .notification .body {
      font-size: 12px;
      color: ${pal.base06};
    }
    .notification .app-name {
      font-size: 10px;
      color: ${pal.base04};
    }
    .notification .time {
      font-size: 10px;
      color: ${pal.base04};
    }
    .widget-title {
      color: ${pal.base05};
      font-size: 13px;
      font-weight: bold;
      padding: 4px 8px;
    }
    .widget-title > button {
      background: rgba(${cssRgb pal.base0D}, 0.14);
      color: ${pal.base05};
      font-size: 12px;
      border-radius: 10px;
      padding: 2px 10px;
    }
    .widget-dnd {
      color: ${pal.base04};
      font-size: 12px;
      padding: 4px 8px;
    }
    .notification-action {
      background: rgba(${cssRgb pal.base01}, 0.6);
      color: ${pal.base05};
      font-size: 12px;
      border-radius: 10px;
    }
  '';

  # hyprlock: frosted blur-over-wallpaper lock
}
