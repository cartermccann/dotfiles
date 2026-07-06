{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Niri Wayland compositor
  programs.niri.enable = true;

  # Ly TUI display manager
  services.displayManager.ly = {
    enable = true;
    settings = {
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

  # Swaylock (screen locker)
  security.pam.services.swaylock = { };

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
    # grabs org.freedesktop.Notifications in ANY session (it hijacked the QS
    # session notification server). Every session has its own daemon now:
    # noctalia (niri), swaync (ferro/waybar), qs-shell (QS).
    waybar
    xwayland-satellite
    networkmanagerapplet
    brightnessctl
    wlsunset
    swaylock-effects
    swayidle
    cliphist
    satty
    swayosd
  ];
}
