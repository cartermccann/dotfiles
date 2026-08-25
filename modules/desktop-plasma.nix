{ user, ... }:

{
  # Conventional, mouse-first desktop session. Plasma's NixOS module supplies
  # the Breeze desktop, its core applications, portals, and SDDM integration.
  services.desktopManager.plasma6.enable = true;

  # Plasma selects KDE's Qt platform integration globally. Stylix's Qt target
  # only supports QtCT, so leave Qt styling to Plasma/Breeze instead of keeping
  # an enabled target that cannot apply and warns on every evaluation.
  home-manager.users.${user}.stylix.targets.qt.enable = false;

  # Use the graphical login manager on kronos while the shared module leaves
  # atlas on Ly. Keep Carter's existing daily-driver session as the initial
  # selection; SDDM can still remember a later per-user choice.
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "hyprland";
}
