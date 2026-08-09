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
  pal = import ../lib/palette.nix;

  # Ly colours are 0x00RRGGBB. The most significant byte is a *styling* flag,
  # not alpha, which is why 0x20000000 below is TB_HI_BLACK rather than a
  # translucent black — and why a plain colour keeps that byte at 00. pal.raw.*
  # is the palette slot without its leading '#'.
  lyColor = raw: "0x00${raw}";

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
    # The greeter is ported from the atlas one (cartermccann/gentoo-dotfiles,
    # system/ly/config.ini) and retinted from lib/palette.nix, so it stops
    # being the last Catppuccin Macchiato surface on a host that is Ouranos
    # everywhere else.
    #
    # Two things did not survive the version gap. Atlas ran an older Ly with
    # `animation_frame_delay = 24` ("higher = slower/calmer; default 5 is
    # frantic"); 1.3.2 has no such key, and the knob that actually paces the
    # animation is now min_refresh_delta, the event-loop timeout. And the
    # atlas file set gameoflife_fg, which is dead weight when the chosen
    # animation is colormix, so it is dropped rather than carried over.
    settings = {
      waylandsessions = "${lySessions}";
      full_color = true;

      bg = lyColor pal.raw.base02; # #171b23 — dark and blue-cast, not black
      fg = lyColor pal.raw.base07; # #f4f7fc — the atlas config's "white"
      border_fg = lyColor pal.raw.base0D; # cobalt accent, on the box border
      error_fg = lyColor pal.raw.base08;

      # The box keeps its border here: that cobalt line IS the accent, which is
      # why hide_borders flips false relative to the config this replaces.
      box_title = "kronos";
      hide_borders = false;
      blank_box = true;
      text_in_center = true;
      margin_box_h = 4;
      margin_box_v = 2;
      input_len = 34;
      edge_margin = 2;

      clock = "%A, %B %d";
      bigclock = "en";
      bigclock_12hr = false; # 24h, matching waybar and the Ouranos prompt
      bigclock_seconds = false; # a ticking seconds column fights the animation

      asterisk = "0x2022"; # bullet instead of *
      hide_version_string = true;
      hide_key_hints = true;
      hide_keyboard_locks = true;

      animation = "colormix";
      animation_timeout_sec = 0; # run for as long as the greeter is up
      colormix_col1 = lyColor pal.raw.base0D; # cobalt — the accent
      colormix_col2 = "0x00102a66"; # deep navy; no palette slot sits this low
      colormix_col3 = "0x20000000"; # TB_HI_BLACK — keeps the base truly black
      min_refresh_delta = 24; # ms per event loop pass — paces the shader

      allow_empty_password = false;
      clear_password = true;
      numlock = false;
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
