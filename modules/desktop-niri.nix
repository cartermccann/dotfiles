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
      bg = "0x00000000";
      fg = "0x00AAAAAA";
      border_fg = "0x00555555";
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
      pkgs.xdg-desktop-portal-gnome # file picker, etc.
      pkgs.xdg-desktop-portal-wlr # screen/window capture for wlroots compositors
    ];
    # Use wlr portal for screenshots/screencasting, gnome for everything else
    config.common = {
      default = [ "gnome" ];
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
    mako
    waybar
    xwayland-satellite
    networkmanagerapplet
    brightnessctl
    wlsunset
    swaylock-effects
    swayidle
  ];
}
