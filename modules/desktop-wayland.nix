{
  config,
  lib,
  pkgs,
  ...
}:

# Shared Wayland base for EVERY session on this host, not a niri-only module
# (it was called desktop-niri.nix, which badly undersold it). Owns the Ly
# display manager, XDG portals, polkit, gnome-keyring, and the terminal /
# launcher / screenshot / clipboard / wallpaper packages that the Hyprland
# sessions depend on just as much as the niri one. desktop-hyprland.nix and
# desktop-niri-noctalia.nix layer session-specific bits on top of this.
let
  # Ly reads a flat directory of .desktop files. Start from the one NixOS
  # generates from sessionPackages, then drop the plain "Niri" tile.
  #
  # Why filter here instead of at the source: programs.niri.enable hard-sets
  # `services.displayManager.sessionPackages = [ cfg.package ]` (niri-flake
  # flake.nix:496), and NixOS rejects a session package whose
  # passthru.providedSessions is empty, so the tile cannot be removed by
  # overriding the package without also rebuilding niri from source. Ly's
  # `settings` is documented as "merged in and overwriting defaults", so
  # pointing waylandsessions at a filtered copy is the cheap, supported route.
  #
  # The plain tile runs `niri-session` against ~/.config/niri/config.kdl, a file
  # this config has never written — the standalone niri session was retired in
  # favour of Niri (Noctalia). Choosing it lands you in niri's compiled-in
  # defaults: no output layout, no keybinds, no shell.
  lySessions = pkgs.runCommand "ly-wayland-sessions" { } ''
    mkdir -p "$out"
    cp ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop "$out"/
    chmod u+w "$out"/*.desktop
    rm -f "$out/niri.desktop"
  '';
in
{
  # Niri compositor. Hyprland is the daily driver; niri is kept as a working
  # fallback session (Niri (Noctalia)), so this stays enabled.
  programs.niri.enable = true;

  # Ly TUI display manager
  services.displayManager.ly = {
    enable = true;
    settings = {
      waylandsessions = "${lySessions}";
      animation = "none";
      hide_borders = true;
      hide_key_hints = true;
      hide_version_string = true;
      bigclock = "en";
      clock = "%A, %B %d";
      bg = "0x0024273a"; # Catppuccin Macchiato base
      fg = "0x00cad3f5"; # Catppuccin Macchiato text
      border_fg = "0x00363a4f"; # Catppuccin Macchiato surface0
      input_len = 40;
      clear_password = true;
      save = true;
    };
  };

  # XDG portals for Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk # file picker, etc. (works with any WM, unlike -gnome which needs Mutter)
      pkgs.xdg-desktop-portal-wlr # screen/window capture for wlroots compositors
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

  # Polkit for privilege escalation
  security.polkit.enable = true;

  # GNOME Keyring
  services.gnome.gnome-keyring.enable = true;

  # Desktop packages
  environment.systemPackages = with pkgs; [
    ghostty
    fuzzel
    swww
    grim
    slurp
    wl-clipboard
    # mako removed: its package ships a dbus-activatable user service that
    # grabs org.freedesktop.Notifications in ANY session (it hijacked another
    # session's notification server). Every session has its own daemon now:
    # noctalia (niri), swaync (waybar Hyprland), Caelestia (its own tile).
    waybar
    xwayland-satellite
    brightnessctl
    wlsunset
    cliphist
    satty
    swayosd
  ];
}
