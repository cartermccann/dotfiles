{
  config,
  pkgs,
  user,
  ...
}:

let
  rice-dashboard = pkgs.writeShellScriptBin "rice-dashboard" ''
    ${pkgs.tmux}/bin/tmux new-session -d -s rice -x "$(tput cols)" -y "$(tput lines)"
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'btop' Enter
    ${pkgs.tmux}/bin/tmux split-window -h -t rice -p 40
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'cava' Enter
    ${pkgs.tmux}/bin/tmux split-window -v -t rice -p 50
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'yazi' Enter
    ${pkgs.tmux}/bin/tmux select-pane -t rice:1.1
    ${pkgs.tmux}/bin/tmux attach -t rice
  '';

  power-menu = pkgs.writeShellScriptBin "power-menu" ''
    CHOICE=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt=" ")
    case "$CHOICE" in
      Lock)     swaylock -f ;;
      Logout)   niri msg action quit ;;
      Suspend)  systemctl suspend ;;
      Reboot)   systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
    esac
  '';
in
{
  home.packages = [ power-menu rice-dashboard ];
  # Niri config (KDL format)
  xdg.configFile."niri/config.kdl".force = true;
  xdg.configFile."niri/config.kdl".text = ''
    // Startup — env import + restart failed portal services, then launch GUI apps
    spawn-at-startup "bash" "-c" "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL GBM_BACKEND NVD_BACKEND LIBVA_DRIVER_NAME __GLX_VENDOR_LIBRARY_NAME && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIXOS_OZONE_WL GBM_BACKEND NVD_BACKEND LIBVA_DRIVER_NAME __GLX_VENDOR_LIBRARY_NAME && systemctl --user restart xdg-desktop-portal-gtk xdg-desktop-portal 2>/dev/null; waybar & mako & nm-applet &"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
    spawn-at-startup "swayosd-server"
    spawn-at-startup "wlsunset" "-t" "3500" "-T" "6500"
    spawn-at-startup "bash" "-c" "sleep 1 && wallpaper-set /home/${user}/wallpaper.png"
    spawn-at-startup "xwayland-satellite"
    spawn-at-startup "easyeffects" "--gapplication-service"
    spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "timeout" "600" "niri msg action power-off-monitors" "before-sleep" "swaylock -f"

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
        scroll-method "two-finger"
      }
    }

    // Layout
    layout {
      gaps 12
      center-focused-column "never"
      default-column-width { proportion 0.5; }
      focus-ring {
        off
      }
      border {
        width 2
        active-gradient from="#81A1C1" to="#8FBCBB" angle=45
        inactive-gradient from="#3B4252" to="#434C5E" angle=45
      }
    }

    // Animations (snappy, critically damped)
    animations {
      window-open {
        duration-ms 150
        curve "ease-out-quad"
      }
      window-close {
        duration-ms 150
        curve "ease-out-quad"
      }
      workspace-switch {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
      }
      window-resize {
        duration-ms 150
        curve "ease-out-quad"
      }
      horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
      }
      window-movement {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
      }
    }

    // Blur settings (global)
    blur {
      passes 3
      offset 3.0
      noise 0.02
      saturation 1.5
    }

    // Window rules
    window-rule {
      geometry-corner-radius 16
      clip-to-geometry true
      shadow {
        on
        color "#00000064"
      }
      background-effect {
        blur true
      }
    }

    // Overview backdrop — show wallpaper behind workspace overview
    overview {
      backdrop-color "#00000080"
    }

    // Layer rules
    layer-rule {
      match namespace="^waybar$"
    }

    layer-rule {
      match namespace="^mako$"
      shadow {
        on
      }
    }

    layer-rule {
      match namespace="^fuzzel$"
      shadow {
        on
      }
    }

    // Screenshots
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"

    // Keybindings
    binds {

      // ── Programs ──
      Mod+Return { spawn "ghostty"; }
      Mod+Space { spawn "fuzzel"; }
      Mod+Shift+S { spawn "bash" "-c" "grim -g \"$(slurp)\" - | satty -f -"; }
      Mod+Shift+P { screenshot-screen; }
      Print { screenshot; }

      // ── Clipboard history ──
      Mod+V { spawn "bash" "-c" "cliphist list | fuzzel --dmenu --prompt='Clipboard: ' | cliphist decode | wl-copy"; }

      // ── Power menu ──
      Mod+Shift+X { spawn "power-menu"; }

      // ── Window management ──
      Mod+W { close-window; }
      Mod+Q { close-window; }

      // ── Vim-style focus (from your niri config) ──
      Mod+H { focus-column-left; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      Mod+L { focus-column-right; }

      // ── Arrow key focus ──
      Mod+Left { focus-column-left; }
      Mod+Down { focus-window-down; }
      Mod+Up { focus-window-up; }
      Mod+Right { focus-column-right; }

      // ── Vim-style move windows ──
      Mod+Shift+H { move-column-left; }
      Mod+Shift+J { move-window-down; }
      Mod+Shift+K { move-window-up; }
      Mod+Shift+L { move-column-right; }

      // ── Arrow key move windows ──
      Mod+Shift+Left { move-column-left; }
      Mod+Shift+Down { move-window-down; }
      Mod+Shift+Up { move-window-up; }
      Mod+Shift+Right { move-column-right; }

      // ── Resize ──
      Mod+Ctrl+H { set-column-width "-10%"; }
      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }

      // ── Layout ──
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+C { center-column; }
      Mod+T { toggle-window-floating; }

      // ── Workspaces 1-10 ──
      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+7 { focus-workspace 7; }
      Mod+8 { focus-workspace 8; }
      Mod+9 { focus-workspace 9; }
      Mod+0 { focus-workspace 10; }

      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }
      Mod+Shift+6 { move-column-to-workspace 6; }
      Mod+Shift+7 { move-column-to-workspace 7; }
      Mod+Shift+8 { move-column-to-workspace 8; }
      Mod+Shift+9 { move-column-to-workspace 9; }
      Mod+Shift+0 { move-column-to-workspace 10; }

      // ── Workspace cycling ──
      Mod+Tab { focus-workspace-down; }
      Mod+Shift+Tab { focus-workspace-up; }

      // ── Notifications ──
      Mod+Comma { spawn "makoctl" "dismiss"; }
      Mod+Shift+Comma { spawn "makoctl" "dismiss" "--all"; }
      Mod+Alt+Comma { spawn "makoctl" "invoke"; }

      // ── Utilities ──
      Mod+Shift+Space { spawn "bash" "-c" "pkill waybar || waybar"; }  // toggle waybar
      Mod+Ctrl+L { spawn "swaylock" "-f"; }                            // lock screen

      // ── Night shift ──
      Mod+Ctrl+N { spawn "bash" "-c" "pkill wlsunset || wlsunset -t 3500 -T 6500"; }

      // ── Dictation ──
      Mod+Alt+L { spawn "bash" "-c" "~/.local/bin/toggle-dictation.sh"; }

      // ── Control panels ──
      Mod+Ctrl+A { spawn "pavucontrol"; }                   // audio controls
      Mod+Ctrl+B { spawn "bluetui"; }                        // bluetooth
      Mod+Ctrl+T { spawn "ghostty" "-e" "btop"; }         // system monitor
      Mod+Ctrl+D { spawn "ghostty" "-e" "rice-dashboard"; } // rice dashboard (btop + cava + yazi)

      // ── Wallpaper & Theme ──
      Mod+Shift+W { spawn "wallpaper-pick"; }
      Mod+Shift+T { spawn "ghostty" "-e" "theme-select"; }

      // ── Session ──
      Mod+Shift+E { quit; }
      Mod+Shift+Slash { show-hotkey-overlay; }

      // ── Audio (media keys — swayosd for visual feedback) ──
      XF86AudioRaiseVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "raise"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "lower"; }
      XF86AudioMute allow-when-locked=true { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
      XF86AudioMicMute allow-when-locked=true { spawn "swayosd-client" "--input-volume" "mute-toggle"; }
      XF86AudioPlay { spawn "playerctl" "play-pause"; }
      XF86AudioNext { spawn "playerctl" "next"; }
      XF86AudioPrev { spawn "playerctl" "previous"; }

      // ── Brightness (swayosd for visual feedback) ──
      XF86MonBrightnessUp allow-when-locked=true { spawn "swayosd-client" "--brightness" "raise"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "swayosd-client" "--brightness" "lower"; }
    }
  '';

  # Fuzzel, mako, swaylock, ghostty, cava configs are generated by matugen templates
  # See home/theme.nix for template definitions

  # Waybar config (JSON — not templated, only CSS changes with theme)
  xdg.configFile."waybar/config".text = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 4;
    modules-left = [ "niri/workspaces" ];
    modules-center = [ "clock" ];
    modules-right = [
      "cpu"
      "memory"
      "network"
      "pulseaudio"
      "bluetooth"
      "tray"
    ];

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
      format-icons.default = [
        ""
        ""
        ""
      ];
      on-click = "pavucontrol";
    };
    bluetooth = {
      format = " {status}";
      format-connected = " {device_alias}";
      on-click = "bluetui";
    };
    clock = {
      format = " {:%H:%M   %a %b %d}";
    };
    tray = {
      spacing = 10;
    };
  };

  # Waybar CSS is generated by matugen (see theme.nix)
}
