{
  config,
  lib,
  pkgs,
  options,
  ...
}:
# Hyprland session. Split by the artifact each part produces rather than kept
# as one file — this was a single 1169-line hyprland.nix generating ten config
# files for six programs.
#
#   scripts.nix     the hypr-* helper scripts
#   compositor.nix  hyprland.lua + hyprsunset.conf
#   waybar.nix      waybar config + stylesheet
#   swaync.nix      notification daemon + stylesheet
#   menus.nix       fuzzel + swayosd
#   lock.nix        hyprlock + hypridle
#   css.nix         shared hex -> "r, g, b" helper (not a module)
#
# Colours come from lib/palette.nix; each module imports it directly rather
# than threading it through, so any one of them can be read on its own.
{
  imports = [
    ./scripts.nix
    ./compositor.nix
    ./waybar.nix
    ./swaync.nix
    ./menus.nix
    ./lock.nix
  ];

  # The hypr-* scripts add themselves in scripts.nix; these are the plain
  # packages the session needs.
  home.packages = [
    pkgs.hyprsunset # night light daemon (autostarted by compositor.nix; hyprland session only)
    pkgs.grimblast # screenshot wrapper (adds --freeze; wraps grim+slurp)
    pkgs.hyprpicker # color picker → clipboard (SUPER+SHIFT+C)
  ];

  # Print-screen target must exist or grimblast silently fails.
  home.file."Pictures/Screenshots/.keep".text = "";

  # Seed ~/wallpaper.png on first activation — *converted*, not copied, so the
  # PNG-named file actually contains PNG bytes (hyprlock requires it).
  home.activation.seedWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    [ -f "$HOME/wallpaper.png" ] || run ${pkgs.imagemagick}/bin/magick ${../../wallpaper/fam.jpg} "$HOME/wallpaper.png"
  '';

  # Hyprland 0.55 dropped hyprlang in favor of Lua (`~/.config/hypr/hyprland.lua`).
  # The home-manager `wayland.windowManager.hyprland` module only emits the old
  # hyprlang `.conf` (which 0.55 ignores), so we bypass it and write the Lua
  # config directly. The compositor + portal come from modules/desktop-hyprland.nix.
  # API reference: $hyprland/share/hypr/stubs/hl.meta.lua

  # Opt the Hyprland session out of global Stylix so it carries the Ouranos
  # palette (same idea as stylix.targets.niri.enable=false in home/shell.nix).
  # Guarded: stylix 25.11 may not declare a `hyprland` target, and if it
  # doesn't, Stylix never touches hypr/ anyway.
  stylix = lib.optionalAttrs (options.stylix.targets ? hyprland) {
    targets.hyprland.enable = false;
  };
}
