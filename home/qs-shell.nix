{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  home.packages = [
    pkgs.quickshell
    # Polkit auth agent for the QS session (autostarted from the qs branch of
    # hyprland.nix). Quickshell 0.2.1 exposes no polkit QML API, so the
    # shell can't render auth dialogs itself — hyprpolkitagent (Qt/QML, made
    # for Hyprland) fills the gap. See qs-shell's DECISIONS.md (M7).
    pkgs.hyprpolkitagent
  ];

  # Out-of-store symlink (not a copy) so QML edits in the repo hot-reload
  # without a home-manager rebuild — that's the whole point of this module.
  xdg.configFile."quickshell/qs-shell".source =
    config.lib.file.mkOutOfStoreSymlink "/home/${user}/projects/qs-shell";
}
