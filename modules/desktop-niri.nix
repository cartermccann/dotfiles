{ config, lib, pkgs, ... }:

{
  # Niri Wayland compositor
  programs.niri.enable = true;

  # greetd + ReGreet (Wayland greeter)
  # programs.regreet enables greetd automatically and runs regreet under cage
  programs.regreet = {
    enable = true;
    settings = {
      GTK = {
        application_prefer_dark_theme = lib.mkForce true;
        cursor_theme_name = lib.mkForce "Bibata-Modern-Ice";
        font_name = lib.mkForce "JetBrainsMono Nerd Font 12";
        icon_theme_name = lib.mkForce "Papirus-Dark";
      };
      background = {
        path = lib.mkForce "/etc/greetd/wallpaper.png";
        fit = lib.mkForce "Cover";
      };
    };
    cageArgs = [ "-s" ];
    extraCss = ''
      window {
        background-size: cover;
        background-position: center;
      }

      .login-box {
        background-color: rgba(0, 0, 0, 0.55);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 20px;
        padding: 40px;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
      }

      entry {
        background-color: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 12px;
        padding: 12px 16px;
        color: rgba(255, 255, 255, 0.9);
      }

      button {
        background-color: rgba(255, 255, 255, 0.12);
        border: 1px solid rgba(255, 255, 255, 0.18);
        border-radius: 12px;
        color: white;
        padding: 10px 24px;
      }
    '';
  };

  # Copy wallpaper for greeter
  environment.etc."greetd/wallpaper.png".source = ../wallpaper/nord-landscape.png;

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
  ];
}
