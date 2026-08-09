{
  config,
  lib,
  ...
}:
# Waybar: the bar config and its stylesheet.
let
  pal = import ../../lib/palette.nix;
  cssRgb = import ./css.nix lib;
in
{
  xdg.configFile."waybar/config".text =
    let
      barBase = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 6;
        margin-top = 8;
        margin-left = 12;
        margin-right = 12;

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          all-outputs = true;
        };
        # Visible only while a submap is active (tmux prefix mode) — the
        # uppercase tracking matches the other HUD micro-labels.
        "hyprland/submap" = {
          format = "{}";
          tooltip = false;
        };
        clock = {
          format = "{:%H:%M  ·  %a %b %d}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
        mpris = {
          format = "{status_icon} {dynamic}";
          dynamic-order = [
            "title"
            "artist"
          ];
          dynamic-len = 28;
          status-icons = {
            playing = "󰐊";
            paused = "󰏤";
            stopped = "󰓛";
          };
          tooltip-format = "{player}: {title} — {artist}";
          # click = play/pause, right-click = next are mpris module defaults
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
          tooltip-format-activated = "caffeine: screen stays on";
          tooltip-format-deactivated = "idle: lock at 5 min";
        };
        "custom/gpu" = {
          exec = "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits";
          format = "GPU {}°";
          interval = 10;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        memory = {
          format = "MEM {percentage}%";
          interval = 5;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        network = {
          format-wifi = "WIFI {signalStrength}%";
          format-ethernet = "ETH";
          format-disconnected = "OFFLINE";
          tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr}\n↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}";
          tooltip-format-wifi = "{essid} ({signalStrength}%): {ipaddr}";
          interval = 10;
          "min-length" = 9;
          on-click = "ghostty --class=TUI.float -e nmtui";
        };
        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "󰂱 {num_connections}";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "ghostty --class=TUI.float -e bluetui";
        };
        # Left-click is the output picker rather than pavucontrol: switching
        # between the desk speakers, the Schiit and Bluetooth headphones is
        # the frequent action, and the full mixer is rarely what's wanted.
        # Middle-click still opens pavucontrol for per-app routing.
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTED";
          scroll-step = 3;
          on-click = "hypr-audio-sink";
          on-click-middle = "pavucontrol";
          on-click-right = "swayosd-client --output-volume mute-toggle";
          tooltip-format = "{desc} — {volume}%";
        };
        "custom/notifications" = {
          format = "{icon}";
          format-icons = {
            notification = "󱅫";
            none = "󰂚";
            dnd-notification = "󰂛";
            dnd-none = "󰂛";
            inhibited-notification = "󱅫";
            inhibited-none = "󰂚";
          };
          return-type = "json";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
          tooltip = false;
        };
        tray = {
          spacing = 10;
          icon-size = 16;
        };
        "custom/power" = {
          format = "⏻";
          on-click = "hypr-power-menu";
          tooltip = false;
        };
      };
    in
    builtins.toJSON [
      (
        barBase
        // {
          output = [ "HDMI-A-1" ];
          modules-left = [
            "hyprland/workspaces"
            "hyprland/submap"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "mpris"
            "idle_inhibitor"
            "custom/gpu"
            "cpu"
            "memory"
            "network"
            "bluetooth"
            "pulseaudio"
            "custom/notifications"
            "tray"
            "custom/power"
          ];
        }
      )
      (
        barBase
        // {
          output = [ "DP-1" ];
          modules-left = [
            "hyprland/workspaces"
            "hyprland/submap"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "pulseaudio"
            "custom/notifications"
          ];
        }
      )
    ];

  xdg.configFile."waybar/style.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
      border: none;
      border-radius: 0;
      min-height: 0;
    }
    window#waybar {
      background: transparent;
      color: ${pal.base05};
    }
    tooltip {
      background: rgba(${cssRgb pal.base01}, 0.95);
      border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
      border-radius: 10px;
    }
    tooltip label {
      color: ${pal.base05};
    }
    /* Floating frosted-glass module groups (Hyprland layer blur does the frosting).
       Site language: borders are NEUTRAL hairlines; accent only where focus lives.
       The inset top highlight is a PillNav-style "liquid sheen". */
    .modules-left,
    .modules-center,
    .modules-right {
      background: rgba(${cssRgb pal.base01}, 0.45);
      border: 1px solid rgba(${cssRgb pal.base05}, 0.07);
      box-shadow: inset 0 1px 0 rgba(${cssRgb pal.base05}, 0.06);
      border-radius: 14px;
      padding: 1px 10px;
      margin: 0 4px;
    }
    #workspaces button {
      color: ${pal.base04};
      padding: 0 9px;
      margin: 2px 2px;
      border-radius: 10px;
      font-size: 12px;
    }
    #workspaces button.active {
      color: ${pal.base07};
      background: rgba(${cssRgb pal.base0D}, 0.18);
    }
    #workspaces button.urgent {
      color: ${pal.base08};
    }
    #workspaces button:hover {
      background: rgba(${cssRgb pal.base05}, 0.06);
    }
    #submap {
      color: ${pal.base0D};
      padding: 0 10px;
      font-size: 11px;
      letter-spacing: 0.08em;
    }
    #clock {
      color: ${pal.base05};
      font-weight: bold;
      padding: 0 10px;
      font-size: 12px;
    }
    #mpris {
      color: ${pal.base06};
      padding: 0 9px;
      font-size: 12px;
    }
    #mpris.paused {
      color: ${pal.base04};
    }
    #idle_inhibitor {
      color: ${pal.base04};
      padding: 0 8px;
    }
    #idle_inhibitor.activated {
      color: ${pal.base0D};
    }
    /* HUD micro-labels: uppercase comes from the module format strings (GTK CSS
       has no text-transform); tracking lives here. mpris exempt — titles keep case. */
    #custom-gpu,
    #cpu,
    #memory,
    #network,
    #bluetooth,
    #pulseaudio {
      color: ${pal.base06};
      padding: 0 9px;
      font-size: 11px;
      letter-spacing: 0.08em;
    }
    #pulseaudio.muted,
    #bluetooth.disabled,
    #network.disconnected {
      color: ${pal.base03};
    }
    #custom-notifications {
      color: ${pal.base06};
      padding: 0 8px;
    }
    #custom-notifications.notification,
    #custom-notifications.inhibited-notification {
      color: ${pal.base0D};
    }
    #custom-notifications.dnd-notification,
    #custom-notifications.dnd-none {
      color: ${pal.base03};
    }
    #tray {
      padding: 0 6px;
    }
    #custom-power {
      color: ${pal.base04};
      padding: 0 10px 0 8px;
    }
    #custom-power:hover {
      color: ${pal.base08};
    }
  '';

  # fuzzel: session launcher (separate config path; launched via --config)
}
