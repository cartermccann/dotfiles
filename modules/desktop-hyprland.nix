{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  # Hyprland compositor (from nixpkgs 25.11 → matches the home-manager module version,
  # portal comes from the same nixpkgs eval, cached on cache.nixos.org = no local compile).
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hyprland's own portal, in ADDITION to the gtk/wlr portals from desktop-niri.nix.
  # Keyed under `hyprland` (XDG_CURRENT_DESKTOP the compositor sets) so it does NOT collide
  # with the `common` portal config the niri module already defines.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
    };
  };

  # PAM service so hyprlock can authenticate.
  security.pam.services.hyprlock = { };

  # Session-specific packages (waybar / fuzzel / swww / grim / slurp / satty / cliphist /
  # wl-clipboard / brightnessctl / playerctl / wlsunset are already pulled in by desktop-niri.nix).
  environment.systemPackages = with pkgs; [
    hyprlock
    hypridle
    swaynotificationcenter
  ];

  # Register a "Hyprland (Comcreate)" login tile next to "Niri (Noctalia)" — same writeTextDir
  # pattern the niri-noctalia module uses. Ly reads sessionPackages automatically, no greeter change.
  # Exec=Hyprland reads ~/.config/hypr/hyprland.conf, which home/hyprland-comcreate.nix writes.
  services.displayManager.sessionPackages = [
    ((pkgs.writeTextDir "share/wayland-sessions/hyprland-comcreate.desktop" ''
      [Desktop Entry]
      Name=Hyprland (Comcreate)
      Comment=Minimalist comcreate-themed Hyprland session
      Exec=Hyprland
      Type=Application
    '').overrideAttrs (_: {
      passthru.providedSessions = [ "hyprland-comcreate" ];
    }))
  ];
}
