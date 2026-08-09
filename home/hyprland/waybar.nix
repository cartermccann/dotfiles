{
  config,
  lib,
  ...
}:
# Waybar: the bar config and its stylesheet.
let
  pal = import ../../lib/palette.nix;
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

  # The stylesheet lives in config/hyprland/waybar.css as real CSS. It carries
  # no Nix interpolation at all: the palette is emitted alongside it as
  # _ouranos.css and pulled in with @import, so the two travel together and the
  # stylesheet stays editable with normal CSS tooling.
  xdg.configFile."waybar/style.css".source = ../../config/hyprland/waybar.css;
  xdg.configFile."waybar/_ouranos.css".text = import ./palette-css.nix lib pal;

  # fuzzel: session launcher (separate config path; launched via --config)
}
