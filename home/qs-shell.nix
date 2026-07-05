{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  home.packages = [ pkgs.quickshell ];

  # Out-of-store symlink (not a copy) so QML edits in the repo hot-reload
  # without a home-manager rebuild — that's the whole point of this module.
  xdg.configFile."quickshell/qs-shell".source =
    config.lib.file.mkOutOfStoreSymlink "/home/${user}/projects/qs-shell";
}
