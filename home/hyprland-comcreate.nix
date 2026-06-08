{
  config,
  lib,
  pkgs,
  options,
  user,
  ...
}:
let
  cc = import ../lib/comcreate-palette.nix;
  cfgHome = config.xdg.configHome;

  waybarCmd = "waybar -c ${cfgHome}/waybar/comcreate-config.jsonc -s ${cfgHome}/waybar/comcreate-style.css";

  # Power menu (Hyprland variant of the niri power-menu — uses hyprlock + hyprctl)
  hypr-power-menu = pkgs.writeShellScriptBin "hypr-power-menu" ''
    CHOICE=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/comcreate.ini --prompt="⏻  ")
    case "$CHOICE" in
      Lock)     ${pkgs.hyprlock}/bin/hyprlock ;;
      Logout)   ${pkgs.hyprland}/bin/hyprctl dispatch exit ;;
      Suspend)  systemctl suspend ;;
      Reboot)   systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
    esac
  '';

  # Wallpaper picker (mirrors niri's; `find -L` is required for the nix-symlinked ~/wallpapers)
  hypr-wallpaper-pick = pkgs.writeShellScriptBin "hypr-wallpaper-pick" ''
    PICK=$(find -L ~/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/comcreate.ini --prompt="Wallpaper: ")
    [ -n "$PICK" ] && cp "$PICK" ~/wallpaper.png \
      && ${pkgs.swww}/bin/swww img "$PICK" --transition-type grow --transition-duration 1
  '';
in
{
  config = lib.mkMerge [
    {
      home.packages = [
        hypr-power-menu
        hypr-wallpaper-pick
      ];

      wayland.windowManager.hyprland = {
        enable = true;
        package = null; # Hyprland is installed by modules/desktop-hyprland.nix — avoid a 2nd copy
        systemd.enable = true;

        settings = {
          monitor = ",preferred,auto,1";

          "$mod" = "SUPER";

          env = [
            "XCURSOR_SIZE,24"
            "HYPRCURSOR_SIZE,24"
          ];

          # NVIDIA: this host's GBM_BACKEND/__GLX_VENDOR_LIBRARY_NAME etc. are already global
          # (modules/nvidia.nix → environment.sessionVariables); only the cursor knob is Hyprland-specific.
          cursor = {
            no_hardware_cursors = true;
          };

          exec-once = [
            # Import env into systemd/dbus then bounce the portals (mirrors the niri startup line)
            "bash -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE NIXOS_OZONE_WL GBM_BACKEND NVD_BACKEND LIBVA_DRIVER_NAME __GLX_VENDOR_LIBRARY_NAME && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal 2>/dev/null'"
            "swww-daemon"
            "wl-paste --watch cliphist store"
            "swayosd-server"
            waybarCmd
            "swaync"
            "hypridle"
            "wlsunset -t 3500 -T 6500 -l 40.76 -L -111.89"
            "sleep 1 && swww img ${config.home.homeDirectory}/wallpaper.png --transition-type grow --transition-duration 1"
          ];

          general = {
            gaps_in = 6;
            gaps_out = 12;
            border_size = 2;
            "col.active_border" = "rgba(7b7bffee) rgba(72b8ffee) 45deg"; # azure gradient
            "col.inactive_border" = "rgba(211e1aaa)";
            layout = "dwindle";
            allow_tearing = false;
            resize_on_border = true;
          };

          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };

          # ── Glassy blur + rounding + soft shadows ──
          decoration = {
            rounding = 14;
            active_opacity = 0.97;
            inactive_opacity = 0.90;
            dim_inactive = true;
            dim_strength = 0.08;
            blur = {
              enabled = true;
              size = 8;
              passes = 3;
              new_optimizations = true;
              ignore_opacity = true;
              vibrancy = 0.18;
              noise = 0.02;
            };
            shadow = {
              enabled = true;
              range = 18;
              render_power = 3;
              color = "rgba(00000055)";
            };
          };

          animations = {
            enabled = true;
            bezier = [
              "easeOutQuad, 0.25, 0.46, 0.45, 0.94"
              "snappy, 0.2, 1.0, 0.3, 1.0"
            ];
            animation = [
              "windows, 1, 2.5, snappy, popin 6%"
              "windowsOut, 1, 2.5, easeOutQuad, popin 6%"
              "border, 1, 5, easeOutQuad"
              "fade, 1, 3, easeOutQuad"
              "workspaces, 1, 3, snappy, slide"
            ];
          };

          input = {
            kb_layout = "us";
            repeat_delay = 200;
            repeat_rate = 35;
            follow_mouse = 1;
            sensitivity = 0;
            touchpad = {
              natural_scroll = true;
              tap-to-click = true;
            };
          };

          gestures = {
            workspace_swipe = true;
            workspace_swipe_distance = 300;
          };

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            vfr = true;
            focus_on_activate = true;
          };

          # ── Frost the bar / launcher / notifications (layer-level blur = real glass) ──
          layerrule = [
            "blur, waybar"
            "ignorezero, waybar"
            "blur, launcher" # fuzzel's layer namespace
            "ignorezero, launcher"
            "blur, swaync-control-center"
            "ignorezero, swaync-control-center"
            "blur, swaync-notification-window"
            "ignorezero, swaync-notification-window"
          ];

          windowrulev2 = [
            "float, class:^(pavucontrol)$"
            "float, class:^(TUI.float)$"
            "float, title:^(Picture-in-Picture)$"
            "opacity 0.94 0.88, class:^(com.mitchellh.ghostty)$"
            "suppressevent maximize, class:.*"
          ];

          bind = [
            # ── Programs ──
            "$mod, RETURN, exec, ghostty"
            "$mod, SPACE, exec, fuzzel --config ${cfgHome}/fuzzel/comcreate.ini"
            "$mod, V, exec, sh -c 'cliphist list | fuzzel --dmenu --config ${cfgHome}/fuzzel/comcreate.ini | cliphist decode | wl-copy'"
            ''$mod SHIFT, S, exec, sh -c 'grim -g "$(slurp)" - | satty -f -' ''
            "$mod SHIFT, P, exec, grim - | wl-copy"
            ", Print, exec, grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"

            # ── Window management ──
            "$mod, Q, killactive"
            "$mod, W, killactive"
            "$mod, F, fullscreen, 1" # maximize (keep gaps/bar)
            "$mod SHIFT, F, fullscreen, 0" # true fullscreen
            "$mod, T, togglefloating"
            "$mod, C, centerwindow"
            "$mod, P, pseudo"
            "$mod, S, togglesplit"

            # ── Vim + arrow focus ──
            "$mod, H, movefocus, l"
            "$mod, J, movefocus, d"
            "$mod, K, movefocus, u"
            "$mod, L, movefocus, r"
            "$mod, left, movefocus, l"
            "$mod, down, movefocus, d"
            "$mod, up, movefocus, u"
            "$mod, right, movefocus, r"

            # ── Vim + arrow move ──
            "$mod SHIFT, H, movewindow, l"
            "$mod SHIFT, J, movewindow, d"
            "$mod SHIFT, K, movewindow, u"
            "$mod SHIFT, L, movewindow, r"
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, down, movewindow, d"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, right, movewindow, r"

            # ── Resize ──
            "$mod, minus, resizeactive, -10% 0"
            "$mod, equal, resizeactive, 10% 0"

            # ── Workspaces 1-10 ──
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"
            "$mod, 0, workspace, 10"
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"
            "$mod SHIFT, 0, movetoworkspace, 10"
            "$mod, TAB, workspace, e+1"
            "$mod SHIFT, TAB, workspace, e-1"

            # ── Notifications (swaync) ──
            "$mod, comma, exec, swaync-client -d -sw" # dismiss latest
            "$mod SHIFT, comma, exec, swaync-client -C -sw" # close all
            "$mod, N, exec, swaync-client -t -sw" # toggle panel

            # ── Control panels ──
            "$mod CTRL, A, exec, pavucontrol"
            "$mod CTRL, B, exec, ghostty --class=TUI.float -e bluetui"
            "$mod CTRL, T, exec, ghostty -e btop"
            "$mod CTRL, D, exec, ghostty -e rice-dashboard"

            # ── Utilities ──
            "$mod CTRL, L, exec, hyprlock"
            "$mod SHIFT, X, exec, hypr-power-menu"
            "$mod SHIFT, W, exec, hypr-wallpaper-pick"
            "$mod SHIFT, SPACE, exec, sh -c 'pkill waybar || ${waybarCmd}'"
            "$mod SHIFT, R, exec, hyprctl reload"
            "$mod CTRL, N, exec, sh -c 'pkill wlsunset || wlsunset -t 3500 -T 6500 -l 40.76 -L -111.89'"
            "$mod ALT, L, exec, sh -c '~/.local/bin/toggle-dictation.sh'"

            # ── Session ──
            "$mod SHIFT, E, exit"
          ];

          # Repeating volume/brightness (locked = works on lock screen), via swayosd for the OSD
          bindel = [
            ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
            ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
            ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
            ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
          ];

          bindl = [
            ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
            ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioNext, exec, playerctl next"
            ", XF86AudioPrev, exec, playerctl previous"
          ];

          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];
        };
      };

      # ── Waybar: dedicated comcreate config/style (separate filenames so it never clobbers
      #    the Stylix-themed default waybar that the niri session uses) ──
      xdg.configFile."waybar/comcreate-config.jsonc".text = builtins.toJSON {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 6;
        margin-top = 8;
        margin-left = 12;
        margin-right = 12;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "cpu" "memory" "network" "pulseaudio" "tray" ];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          all-outputs = true;
        };
        clock = {
          format = "{:%H:%M  ·  %a %b %d}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
        cpu = {
          format = "cpu {usage}%";
          interval = 5;
        };
        memory = {
          format = "mem {percentage}%";
          interval = 5;
        };
        network = {
          format-wifi = "{essid}";
          format-ethernet = "eth";
          format-disconnected = "offline";
        };
        pulseaudio = {
          format = "vol {volume}%";
          format-muted = "muted";
          on-click = "pavucontrol";
        };
        tray = {
          spacing = 10;
        };
      };

      xdg.configFile."waybar/comcreate-style.css".text = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          border: none;
          border-radius: 0;
          min-height: 0;
        }
        window#waybar {
          background: transparent;
          color: ${cc.base05};
        }
        /* Floating frosted-glass module groups (Hyprland layer blur does the frosting) */
        .modules-left,
        .modules-center,
        .modules-right {
          background: rgba(27, 25, 23, 0.55); /* base01 @ 55% */
          border: 1px solid rgba(123, 123, 255, 0.18); /* faint azure edge */
          border-radius: 14px;
          padding: 1px 8px;
          margin: 0 4px;
        }
        #workspaces button {
          color: ${cc.base04};
          padding: 0 9px;
          margin: 2px 2px;
          border-radius: 10px;
        }
        #workspaces button.active {
          color: ${cc.base05};
          background: rgba(123, 123, 255, 0.14);
          box-shadow: inset 0 -2px ${cc.accent}; /* azure underline */
        }
        #workspaces button:hover {
          background: rgba(232, 228, 223, 0.06);
          box-shadow: none;
        }
        #clock {
          color: ${cc.base05};
          font-weight: bold;
          padding: 0 10px;
        }
        #cpu,
        #memory,
        #network,
        #pulseaudio {
          color: ${cc.base06};
          padding: 0 9px;
        }
        #pulseaudio.muted {
          color: ${cc.base03};
        }
        #tray {
          padding: 0 6px;
        }
      '';

      # ── fuzzel: comcreate launcher (separate config path; launched via --config) ──
      xdg.configFile."fuzzel/comcreate.ini".text = ''
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
        background=141210ee
        text=e8e4dfff
        prompt=8a847cff
        placeholder=6b655dff
        input=e8e4dfff
        match=7b7bffff
        selection=211e1aff
        selection-text=f2efe9ff
        selection-match=72b8ffff
        border=7b7bffff

        [border]
        width=2
        radius=14
      '';

      # ── swaync: glassy notification center ──
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
        widgets = [ "title" "dnd" "notifications" ];
        widget-config = {
          title = {
            text = "comcreate";
            clear-all-button = true;
            button-text = "clear";
          };
          dnd = {
            text = "do not disturb";
          };
        };
      };

      xdg.configFile."swaync/style.css".text = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
        }
        .control-center {
          background: rgba(20, 18, 16, 0.7);
          color: ${cc.base05};
          border: 1px solid rgba(123, 123, 255, 0.18);
          border-radius: 16px;
          margin: 8px;
          padding: 12px;
        }
        .notification-row .notification-background .notification {
          background: rgba(27, 25, 23, 0.78);
          color: ${cc.base05};
          border: 1px solid rgba(123, 123, 255, 0.14);
          border-radius: 14px;
          margin: 6px 4px;
          padding: 4px;
        }
        .notification-row .notification-background .notification.critical {
          border-color: ${cc.base08};
        }
        .widget-title {
          color: ${cc.base05};
          font-weight: bold;
          padding: 4px 8px;
        }
        .widget-title > button {
          background: rgba(123, 123, 255, 0.14);
          color: ${cc.base05};
          border-radius: 10px;
          padding: 2px 10px;
        }
        .widget-dnd {
          color: ${cc.base04};
          padding: 4px 8px;
        }
        .notification-action {
          background: rgba(27, 25, 23, 0.6);
          color: ${cc.base05};
          border-radius: 10px;
        }
      '';

      # ── hyprlock: frosted blur-over-wallpaper lock ──
      xdg.configFile."hypr/hyprlock.conf".text = ''
        background {
          monitor =
          path = ${config.home.homeDirectory}/wallpaper.png
          blur_passes = 3
          blur_size = 8
          noise = 0.02
          contrast = 0.9
          brightness = 0.7
          vibrancy = 0.18
        }

        input-field {
          monitor =
          size = 280, 50
          outline_thickness = 2
          dots_size = 0.25
          dots_spacing = 0.3
          outer_color = rgba(7b7bffee)
          inner_color = rgba(1b1917cc)
          font_color = rgba(e8e4dfff)
          placeholder_text = <span foreground="##8a847c">comcreate</span>
          rounding = 14
          fade_on_empty = false
          position = 0, -40
          halign = center
          valign = center
        }

        label {
          monitor =
          text = $TIME
          font_size = 64
          font_family = JetBrainsMono Nerd Font
          color = rgba(e8e4dfff)
          position = 0, 120
          halign = center
          valign = center
        }

        label {
          monitor =
          text = cmd[update:60000] date +"%A, %B %d"
          font_size = 18
          font_family = JetBrainsMono Nerd Font
          color = rgba(c5bfb5cc)
          position = 0, 60
          halign = center
          valign = center
        }
      '';

      # ── hypridle: lock → dpms off → suspend ──
      xdg.configFile."hypr/hypridle.conf".text = ''
        general {
          lock_cmd = pidof hyprlock || hyprlock
          before_sleep_cmd = loginctl lock-session
          after_sleep_cmd = hyprctl dispatch dpms on
        }

        listener {
          timeout = 300
          on-timeout = loginctl lock-session
        }

        listener {
          timeout = 360
          on-timeout = hyprctl dispatch dpms off
          on-resume = hyprctl dispatch dpms on
        }

        listener {
          timeout = 600
          on-timeout = systemctl suspend
        }
      '';
    }

    # Opt the Hyprland session OUT of global Stylix so it carries the comcreate palette —
    # same precedent as stylix.targets.niri.enable=false in home/shell.nix. Guarded because
    # stylix 25.11 may not declare a `hyprland` target (research couldn't confirm); if absent,
    # Stylix never touches hypr/ anyway and the hand-coded colors win regardless.
    (lib.optionalAttrs (options.stylix.targets ? hyprland) {
      stylix.targets.hyprland.enable = false;
    })
  ];
}
