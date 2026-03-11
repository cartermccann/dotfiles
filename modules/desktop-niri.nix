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
      ((pkgs.sddm-astronaut.override {
        embeddedTheme = "japanese_aesthetic";
        themeConfig = {
          Background = "${../wallpaper/nord-landscape.png}";
          DimBackground = "0.3";
          FormBackgroundColor = "#2E3440";
          BackgroundColor = "#2E3440";
          DimBackgroundColor = "#2E3440";
          LoginFieldBackgroundColor = "#3B4252";
          PasswordFieldBackgroundColor = "#3B4252";
          LoginFieldTextColor = "#D8DEE9";
          PasswordFieldTextColor = "#D8DEE9";
          UserIconColor = "#81A1C1";
          PasswordIconColor = "#81A1C1";
          PlaceholderTextColor = "#4C566A";
          WarningColor = "#BF616A";
          LoginButtonTextColor = "#ECEFF4";
          LoginButtonBackgroundColor = "#81A1C1";
          SystemButtonsIconsColor = "#D8DEE9";
          SessionButtonTextColor = "#D8DEE9";
          DropdownTextColor = "#D8DEE9";
          DropdownSelectedBackgroundColor = "#434C5E";
          DropdownBackgroundColor = "#3B4252";
          HighlightTextColor = "#88C0D0";
          HighlightBackgroundColor = "#3B4252";
          HighlightBorderColor = "#81A1C1";
          HoverUserIconColor = "#88C0D0";
          HoverPasswordIconColor = "#88C0D0";
          HoverSystemButtonsIconsColor = "#88C0D0";
          HoverSessionButtonTextColor = "#88C0D0";
          HeaderTextColor = "#ECEFF4";
          DateTextColor = "#D8DEE9";
          TimeTextColor = "#ECEFF4";
        };
      }).overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          # Patch theme config with Nord colors (in case themeConfig overrides aren't applied)
          conf="$out/share/sddm/themes/sddm-astronaut-theme/Themes/japanese_aesthetic.conf"
          if [ -f "$conf" ]; then
            substituteInPlace "$conf" \
              --replace-quiet 'LoginFieldTextColor="#32302f"' 'LoginFieldTextColor="#D8DEE9"' \
              --replace-quiet 'PasswordFieldTextColor="#32302f"' 'PasswordFieldTextColor="#D8DEE9"' \
              --replace-quiet 'PlaceholderTextColor="#7c6f64"' 'PlaceholderTextColor="#4C566A"' \
              --replace-quiet 'LoginFieldBackgroundColor="#1d2021"' 'LoginFieldBackgroundColor="#3B4252"'
          fi

          # Fix hardcoded 0.2 opacity on input backgrounds
          input="$out/share/sddm/themes/sddm-astronaut-theme/Components/Input.qml"
          if [ -f "$input" ]; then
            substituteInPlace "$input" \
              --replace-quiet 'opacity: 0.2' 'opacity: 0.6'
          fi
        '';
      }))
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
  ];
}
