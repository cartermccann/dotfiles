{
  pkgs,
  noctalia,
  user,
  ...
}:

{
  environment.systemPackages = [
    noctalia.packages.${pkgs.system}.default
  ];

  # Battery / power management (needed by Noctalia's built-in widgets)
  services.upower.enable = true;

  # Register a "Niri (Noctalia)" session in the display manager
  services.displayManager.sessionPackages = [
    ((pkgs.writeTextDir "share/wayland-sessions/niri-noctalia.desktop" ''
      [Desktop Entry]
      Name=Niri (Noctalia)
      Comment=Niri compositor with Noctalia shell
      Exec=niri --config /home/${user}/.config/niri/config-noctalia.kdl
      Type=Application
    '').overrideAttrs (_: {
      passthru.providedSessions = [ "niri-noctalia" ];
    }))
  ];
}
