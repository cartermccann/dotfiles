{ pkgs, ... }:

{
  stylix = {
    enable = true;
    polarity = "dark";
    image = ../wallpaper/fam.jpg;
    # Ouranos, the house palette (lib/palette.nix via lib/ouranos.nix), so GTK,
    # btop, bat, fzf, tmux, yazi, lazygit and the rest match the Hyprland
    # session instead of running catppuccin-macchiato beside it. Not covered:
    # Qt (desktop-plasma.nix hands it to Plasma/Breeze) and Zen (installed as a
    # system package; the Stylix target needs an HM-managed Zen profile).
    base16Scheme = (import ../lib/ouranos.nix).base16;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
  };
}
