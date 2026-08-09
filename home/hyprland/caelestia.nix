{
  lib,
  pkgs,
  caelestia,
  ...
}:
# Caelestia: the Quickshell-based shell behind the "Hyprland (Caelestia)" login
# tile. It replaces waybar + swaync + fuzzel + swayosd wholesale for that
# session — bar, notifications, launcher, OSD and lock screen all come from it.
#
# Deliberately NOT themed from lib/palette.nix. Caelestia derives its own
# Material colour scheme and owns that end to end; wiring Ouranos into it would
# mean fighting a system that already works. The Ouranos palette stays with the
# waybar session and Ghostty.
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ caelestia.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    package = caelestia.packages.${system}.with-cli;
    cli.enable = true;

    # The upstream module binds a systemd user service to
    # `wayland.systemd.target` (graphical-session.target). That target is
    # reached by EVERY Wayland session here, so leaving it on would start
    # Caelestia underneath waybar in the plain Hyprland session and again in
    # niri — two shells drawing two bars. The session owns its own shell, so it
    # is launched from the compositor autostart in compositor.nix instead
    # (shellKind = "caelestia"), which is session-scoped by construction. Same
    # reasoning as hyprsunset being a plain autostart rather than a unit.
    systemd.enable = false;

    settings = {
      background = {
        # swww owns the wallpaper on this machine across all three sessions,
        # and ~/wallpaper.png is a cross-session contract (niri autostart,
        # hyprlock background, both wallpaper pickers). Leaving Caelestia's own
        # wallpaper layer on would put a second wallpaper *above* swww's on the
        # Background layer. false keeps the surface — the desktop clock and
        # visualiser still draw — but paints it transparent so swww shows
        # through. Same call as Noctalia's wallpaper module being disabled.
        wallpaperEnabled = false;
      };

      # Point the picker at the shared wallpaper dir rather than its default
      # ~/Pictures/Wallpapers, which does not exist here.
      paths.wallpaperDir = "~/wallpapers";
    };
  };
}
