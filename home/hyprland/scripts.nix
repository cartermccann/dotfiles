{
  config,
  pkgs,
  hyprland,
  ...
}:
# The hypr-* helper scripts. The compositor config invokes these by name off
# PATH, not by store path, so this module has no consumers to coordinate with.
let
  cfgHome = config.xdg.configHome;
  hyprctl = "${hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland}/bin/hyprctl";
  # Power menu (Hyprland variant of the niri power-menu — uses hyprlock + hyprctl)
  hyprPowerMenu = pkgs.writeShellScriptBin "hypr-power-menu" ''
    CHOICE=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini --prompt="⏻  ")
    case "$CHOICE" in
      Lock)     ${pkgs.hyprlock}/bin/hyprlock ;;
      Logout)   ${hyprctl} dispatch 'hl.dsp.exit()' ;;
      Suspend)  systemctl suspend ;;
      Reboot)   systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
    esac
  '';

  # Wallpaper picker (mirrors niri's; `find -L` is required for the nix-symlinked ~/wallpapers).
  # ~/wallpaper.png is a CROSS-SESSION contract (niri autostart, hyprlock background, both
  # pickers) — `magick` writes real PNG bytes there regardless of the source format, so
  # hyprlock and the niri session never see JPEG-bytes-named-png.
  hyprWallpaperPick = pkgs.writeShellScriptBin "hypr-wallpaper-pick" ''
    PICK=$(find -L ~/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini --prompt="Wallpaper: ")
    [ -n "$PICK" ] || exit 0
    ${pkgs.imagemagick}/bin/magick "$PICK" ~/wallpaper.png
    # Grow the new wallpaper out from the cursor; fall back to 0,0 when invoked
    # outside Hyprland (the script is niri-safe by construction).
    POS=$(${hyprctl} cursorpos 2>/dev/null | tr -d ' ')
    [ -n "$POS" ] || POS="0,0"
    ${pkgs.swww}/bin/swww img ~/wallpaper.png \
      --transition-type grow --transition-pos "$POS" \
      --transition-fps 165 --transition-duration 0.7 --transition-bezier .05,.7,.1,1
  '';

  # Audio output picker. Three outputs are in regular rotation (FIIO SA1 desk
  # speakers, Schiit Gunnr for the Arya, Bluetooth headphones) and the only way
  # to switch was a pavucontrol round-trip.
  #
  # Switching the default is enough to move audio: every stream here runs with
  # target.object=auto, so they follow the default rather than pinning to a
  # device. Verified by flipping a live Zen stream between sinks.
  #
  # The awk pass strips wpctl's tree glyphs and the "*" that marks the current
  # default, leaving "<id>. <description>"; the id is recovered from the pick.
  # Monitor sources and the EasyEffects virtual sink are filtered out — the
  # former are not real outputs, and the latter is a processing stage, not a
  # destination (picking it is what made volume keys feel broken).
  hyprAudioSink = pkgs.writeShellScriptBin "hypr-audio-sink" ''
    LIST=$(${pkgs.wireplumber}/bin/wpctl status \
      | ${pkgs.gawk}/bin/awk '/^ ├─ Sinks:/{s=1;next} /^ ├─ Sources:/{s=0} s' \
      | ${pkgs.gnused}/bin/sed 's/^[^0-9*]*//; s/^\*[[:space:]]*/ /' \
      | ${pkgs.gnugrep}/bin/grep -E '^[[:space:]]*[0-9]+\.' \
      | ${pkgs.gnugrep}/bin/grep -viE 'easy effects|monitor' \
      | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//; s/[[:space:]]*\[vol:.*$//')

    [ -n "$LIST" ] || exit 0

    PICK=$(printf '%s' "$LIST" \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini --prompt="󰓃  ")
    [ -n "$PICK" ] || exit 0

    ID=''${PICK%%.*}
    case "$ID" in
      ""|*[!0-9]*) exit 0 ;;
    esac

    ${pkgs.wireplumber}/bin/wpctl set-default "$ID" || exit 1

    NAME=$(printf '%s' "$PICK" | ${pkgs.gnused}/bin/sed 's/^[0-9]*\.[[:space:]]*//')
    ${pkgs.libnotify}/bin/notify-send -a "audio" -i audio-speakers \
      -h string:x-canonical-private-synchronous:audio-sink \
      "Output" "$NAME"
  '';

  # Night-light toggle via hyprsunset's hyprctl IPC (replaces the wlsunset pkill dance)
  hyprNightToggle = pkgs.writeShellScriptBin "hypr-night-toggle" ''
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/.hypr-night-on"
    if [ -f "$STATE" ]; then
      ${hyprctl} hyprsunset identity && rm -f "$STATE"
    else
      ${hyprctl} hyprsunset temperature 3500 && touch "$STATE"
    fi
  '';

  # Single session now: waybar + fuzzel + swaync + swayosd. This used to take a
  # `shellKind` argument and branch on "waybar" vs "qs" throughout; the qs-shell
in
{
  home.packages = [
    hyprPowerMenu
    hyprWallpaperPick
    hyprAudioSink
    hyprNightToggle
  ];
}
