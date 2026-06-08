{
  config,
  pkgs,
  user,
  ...
}:
# The standalone "plain Niri" session (its own config.kdl + Stylix waybar) was
# retired 2026-06-08 — only Niri-Noctalia and Hyprland (Comcreate) remain. This
# file now just provides the cross-session helper scripts those two sessions
# still call (rice-dashboard from both; wallpaper-pick from Niri-Noctalia).
let
  rice-dashboard = pkgs.writeShellScriptBin "rice-dashboard" ''
    ${pkgs.tmux}/bin/tmux new-session -d -s rice -x "$(tput cols)" -y "$(tput lines)"
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'btop' Enter
    ${pkgs.tmux}/bin/tmux split-window -h -t rice -p 40
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'cava' Enter
    ${pkgs.tmux}/bin/tmux split-window -v -t rice -p 50
    ${pkgs.tmux}/bin/tmux send-keys -t rice 'yazi' Enter
    ${pkgs.tmux}/bin/tmux select-pane -t rice:1.1
    ${pkgs.tmux}/bin/tmux attach -t rice
  '';

  wallpaper-pick = pkgs.writeShellScriptBin "wallpaper-pick" ''
    PICK=$(find -L ~/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt="Wallpaper: ")
    [ -n "$PICK" ] && cp "$PICK" ~/wallpaper.png && swww img "$PICK" --transition-type fade --transition-duration 1
  '';
in
{
  home.packages = [ wallpaper-pick rice-dashboard ];
}
