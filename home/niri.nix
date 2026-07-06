{
  config,
  pkgs,
  user,
  ...
}:
# The standalone "plain Niri" session was retired; only Niri-Noctalia and
# the Hyprland sessions remain. This file provides the cross-session helper scripts
# both still call (rice-dashboard from both; wallpaper-pick from Niri-Noctalia).
let
  riceDashboard = pkgs.writeShellScriptBin "rice-dashboard" ''
    ${pkgs.tmux}/bin/tmux new-session -d -s rice -x "$(tput cols)" -y "$(tput lines)"
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'btop' Enter
    ${pkgs.tmux}/bin/tmux split-window -h -t rice -p 40
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'cava' Enter
    ${pkgs.tmux}/bin/tmux split-window -v -t rice -p 50
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'yazi' Enter
    ${pkgs.tmux}/bin/tmux select-pane -t rice:1.1
    ${pkgs.tmux}/bin/tmux attach -t rice
  '';

  wallpaperPick = pkgs.writeShellScriptBin "wallpaper-pick" ''
    PICK=$(find -L ~/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt="Wallpaper: ")
    # ~/wallpaper.png is a cross-session contract (hyprlock reads it too) — `magick`
    # writes real PNG bytes regardless of the source format, where `cp` lied about
    # the extension for jpg picks.
    [ -n "$PICK" ] || exit 0
    ${pkgs.imagemagick}/bin/magick "$PICK" ~/wallpaper.png
    swww img ~/wallpaper.png --transition-type fade --transition-duration 1
  '';
in
{
  home.packages = [
    wallpaperPick
    riceDashboard
  ];
}
