{
  config,
  lib,
  pkgs,
  user,
  hyprland,
  ...
}:

let
  hyprPkgs = hyprland.packages.${pkgs.stdenv.hostPlatform.system};
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
      default = [
        "hyprland"
        "gtk"
      ];
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

  # No custom login tile for the waybar variant: programs.hyprland registers a
  # plain "Hyprland" session, and the ferro theming lives in
  # ~/.config/hypr/hyprland.lua, so that stock tile already loads this exact
  # look. The Quickshell variant needs its own tile since it points at a
  # different Lua config (~/.config/hypr/hyprland-qs.lua).
  services.displayManager.sessionPackages = [
    (
      (pkgs.writeTextDir "share/wayland-sessions/hyprland-qs.desktop" ''
        [Desktop Entry]
        Name=Hyprland (QS)
        Comment=Hyprland with qs-shell (Quickshell)
        # start-hyprland is 0.55's watchdog launcher (bare Hyprland shows a
        # "started without start-hyprland" error overlay in-session, and that
        # overlay is itself a top layer that shoves other surfaces down).
        # Args after `--` are forwarded to Hyprland.
        Exec=start-hyprland -- --config /home/${user}/.config/hypr/hyprland-qs.lua
        Type=Application
      '').overrideAttrs
      (_: {
        passthru.providedSessions = [ "hyprland-qs" ];
      })
    )
  ];
}
