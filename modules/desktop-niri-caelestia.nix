{
  pkgs,
  user,
  ...
}:

{
  # Caelestia shell is installed + started via home-manager
  # (see home/niri-caelestia.nix). No package install needed here.

  # Register a "Niri (Caelestia)" session in the display manager
  services.displayManager.sessionPackages = [
    ((pkgs.writeTextDir "share/wayland-sessions/niri-caelestia.desktop" ''
      [Desktop Entry]
      Name=Niri (Caelestia)
      Comment=Niri compositor with Caelestia shell
      Exec=niri --config /home/${user}/.config/niri/config-caelestia.kdl
      Type=Application
    '').overrideAttrs (_: {
      passthru.providedSessions = [ "niri-caelestia" ];
    }))
  ];
}
