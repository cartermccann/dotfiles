{ config, lib, pkgs, ... }:

{
  # Niri Wayland compositor
  programs.niri.enable = true;

  # greetd display manager with tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

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
    alacritty
    fuzzel
    swaybg
    grim
    slurp
    wl-clipboard
    mako
    waybar
    xwayland-satellite
    networkmanagerapplet
    pavucontrol
    brightnessctl
  ];
}
