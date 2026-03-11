{ config, lib, pkgs, ... }:

{
  # Niri Wayland compositor
  programs.niri.enable = true;

  # SDDM display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [
      (pkgs.sddm-astronaut.override { embeddedTheme = "japanese_aesthetic"; })
    ];
  };

  # Swaylock (screen locker)
  security.pam.services.swaylock = {};

  # XDG portals for Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
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
    pavucontrol
    brightnessctl
    wlsunset
    swaylock-effects
    swayidle
    (sddm-astronaut.override { embeddedTheme = "japanese_aesthetic"; })
  ];
}
