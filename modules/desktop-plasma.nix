{ user, ... }:

{
  # Conventional, mouse-first desktop session. Plasma's NixOS module supplies
  # the Breeze desktop, its core applications, portals, and SDDM integration.
  services.desktopManager.plasma6.enable = true;

  # Plasma selects KDE's Qt platform integration globally. Stylix's Qt target
  # only supports QtCT, so leave Qt styling to Plasma/Breeze instead of keeping
  # an enabled target that cannot apply and warns on every evaluation.
  home-manager.users.${user}.stylix.targets.qt.enable = false;

  # Plasma enables SDDM by default. Keep Ly as the single login manager and
  # expose Plasma only as another session in Ly's chooser.
  services.displayManager.sddm.enable = false;
}
