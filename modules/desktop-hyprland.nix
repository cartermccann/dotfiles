{
  config,
  lib,
  pkgs,
  user,
  hyprland,
  ...
}:

let
  hyprPkgs = hyprland.packages.${pkgs.system};
in
{
  # Hyprland compositor — pinned 0.55.x from the upstream flake (Lua config era).
  # portalPackage is taken from the same flake eval so the compositor and its
  # portal stay version-matched; both come prebuilt from hyprland.cachix.org.
  programs.hyprland = {
    enable = true;
    package = hyprPkgs.hyprland;
    portalPackage = hyprPkgs.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  # Hyprland's portal is already installed via programs.hyprland.portalPackage above;
  # here we only declare the portal routing. Keyed under `hyprland` (the
  # XDG_CURRENT_DESKTOP the compositor sets) so it does NOT collide with the
  # `common` portal config the niri module already defines.
  xdg.portal = {
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

  # No custom login tile: programs.hyprland already registers a plain "Hyprland"
  # session (Exec=start-hyprland, the upstream-recommended launcher). Since the
  # ferro theming lives entirely in the user-global ~/.config/hypr/hyprland.lua,
  # that stock "Hyprland" tile loads this exact look — so we drop the former
  # "Hyprland (Ferro)" tile rather than show a redundant, differently-named one.
}
