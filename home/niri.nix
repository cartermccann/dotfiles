{ config, pkgs, ... }:

{
  # Niri config (KDL format)
  xdg.configFile."niri/config.kdl".text = ''
    // Startup processes
    spawn-at-startup "swaybg" "-m" "fill" "-i" "/home/carter/wallpaper.png"
    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "nm-applet"
    spawn-at-startup "xwayland-satellite"

    // Input
    input {
      keyboard {
        repeat-delay 200
        repeat-rate 35
        xkb {
          layout "us"
        }
      }
      touchpad {
        tap
        natural-scroll
      }
    }

    // Layout
    layout {
      gaps 8
      center-focused-column "never"
      default-column-width { proportion 0.5; }
      focus-ring {
        width 2
        active-color "#81A1C1"
        inactive-color "#3B4252"
      }
      border {
        off
      }
    }

    // Window rules
    window-rule {
      geometry-corner-radius 8
      clip-to-geometry true
    }

    // Screenshots
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"

    // Keybindings
    binds {
      // Programs
      Mod+Return { spawn "alacritty"; }
      Mod+D { spawn "fuzzel"; }
      Mod+Shift+S { screenshot; }
      Mod+Shift+P { screenshot-screen; }

      // Window management
      Mod+Q { close-window; }
      Mod+H { focus-column-left; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      Mod+L { focus-column-right; }
      Mod+Shift+H { move-column-left; }
      Mod+Shift+J { move-window-down; }
      Mod+Shift+K { move-window-up; }
      Mod+Shift+L { move-column-right; }

      // Resize
      Mod+Ctrl+H { set-column-width "-10%"; }
      Mod+Ctrl+L { set-column-width "+10%"; }

      // Layout
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+C { center-column; }

      // Workspaces
      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }
      Mod+Shift+6 { move-column-to-workspace 6; }

      // Session
      Mod+Shift+E { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }

      // Audio
      XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

      // Brightness
      XF86MonitorBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
      XF86MonitorBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }
    }
  '';

  # Fuzzel launcher
  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=12
    terminal=alacritty
    layer=overlay
    prompt="  "

    [colors]
    background=2E3440ff
    text=D8DEE9ff
    match=88C0D0ff
    selection=3B4252ff
    selection-text=ECEff4ff
    border=81A1C1ff

    [border]
    width=2
    radius=8
  '';

  # Mako notifications
  xdg.configFile."mako/config".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color=#2E3440
    text-color=#D8DEE9
    border-color=#81A1C1
    border-size=2
    border-radius=8
    default-timeout=5000
    padding=12
    margin=8
    width=350
    max-visible=3

    [urgency=high]
    border-color=#BF616A
    default-timeout=10000
  '';

  # Waybar
  xdg.configFile."waybar/config".text = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 4;
    modules-left = [ "niri/workspaces" ];
    modules-center = [ "clock" ];
    modules-right = [ "cpu" "memory" "network" "pulseaudio" "tray" ];

    "niri/workspaces" = {
      format = "{index}";
    };
    cpu = {
      format = " {usage}%";
      interval = 5;
    };
    memory = {
      format = " {percentage}%";
      interval = 5;
    };
    network = {
      format-wifi = " {essid}";
      format-ethernet = " {ifname}";
      format-disconnected = " Disconnected";
    };
    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = " Muted";
      format-icons.default = [ "" "" "" ];
      on-click = "pavucontrol";
    };
    clock = {
      format = " {:%H:%M   %a %b %d}";
    };
    tray = {
      spacing = 10;
    };
  };

  xdg.configFile."waybar/style.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: #2E3440;
      color: #D8DEE9;
      border-bottom: 2px solid #3B4252;
    }

    #workspaces button {
      padding: 0 8px;
      color: #4C566A;
      border: none;
      border-radius: 0;
    }

    #workspaces button.active {
      color: #81A1C1;
      border-bottom: 2px solid #81A1C1;
    }

    #cpu, #memory, #network, #pulseaudio, #clock, #tray {
      padding: 0 10px;
    }

    #cpu { color: #88C0D0; }
    #memory { color: #81A1C1; }
    #network { color: #A3BE8C; }
    #pulseaudio { color: #EBCB8B; }
    #clock { color: #D8DEE9; }
  '';
}
