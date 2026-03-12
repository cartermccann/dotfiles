{ config, pkgs, user, matugen, ... }:

let
  matugenPkg = matugen.packages.${pkgs.system}.default;

  wallpaper-set = pkgs.writeShellScriptBin "wallpaper-set" ''
    WALLPAPER="$1"
    if [ -z "$WALLPAPER" ]; then
      echo "Usage: wallpaper-set <image-path>"
      exit 1
    fi
    # Set wallpaper with transition
    ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type grow --transition-duration 1.5
    # Remove home-manager symlink if present, then copy for persistence
    [ -L ~/wallpaper.png ] && rm ~/wallpaper.png
    cp -f "$WALLPAPER" ~/wallpaper.png
    # Regenerate all theme configs from wallpaper colors (non-interactive)
    mkdir -p "$HOME/.config/matugen/generated"
    ${matugenPkg}/bin/matugen image "$WALLPAPER" --source-color-index 0
    # Merge matugen-generated palette into starship.toml
    STARSHIP_BASE="$HOME/.config/starship.toml"
    STARSHIP_PALETTE="$HOME/.config/matugen/generated/starship-palette.toml"
    if [ -f "$STARSHIP_BASE" ] && [ -f "$STARSHIP_PALETTE" ]; then
      # Replace home-manager symlink with a mutable copy
      if [ -L "$STARSHIP_BASE" ]; then
        cp --remove-destination "$(readlink -f "$STARSHIP_BASE")" "$STARSHIP_BASE"
      fi
      ${pkgs.gawk}/bin/awk '
        /^\[palettes\.matugen\]/ { skip=1; next }
        /^\[/ { skip=0 }
        !skip
      ' "$STARSHIP_BASE" > "$STARSHIP_BASE.tmp" && mv "$STARSHIP_BASE.tmp" "$STARSHIP_BASE"
      echo "" >> "$STARSHIP_BASE"
      cat "$STARSHIP_PALETTE" >> "$STARSHIP_BASE"
    fi
    # Apply matugen-generated colors to niri border config
    NIRI_COLORS="$HOME/.config/matugen/generated/niri-colors"
    NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    if [ -f "$NIRI_COLORS" ] && [ -f "$NIRI_CONFIG" ]; then
      source "$NIRI_COLORS"
      # Replace home-manager symlink with a mutable copy
      if [ -L "$NIRI_CONFIG" ]; then
        cp --remove-destination "$(readlink -f "$NIRI_CONFIG")" "$NIRI_CONFIG"
      fi
      ${pkgs.gnused}/bin/sed -i "s/active-color \"#[0-9A-Fa-f]\{6\}\"/active-color \"$NIRI_ACTIVE_COLOR\"/" "$NIRI_CONFIG"
      ${pkgs.gnused}/bin/sed -i "s/inactive-color \"#[0-9A-Fa-f]\{6\}\"/inactive-color \"$NIRI_INACTIVE_COLOR\"/" "$NIRI_CONFIG"
      niri msg action reload-config 2>/dev/null || true
    fi
  '';

  wallpaper-pick = pkgs.writeShellScriptBin "wallpaper-pick" ''
    WALL=$(find ~/wallpapers -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | sort | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt="Wallpaper: ")
    [ -n "$WALL" ] && ${wallpaper-set}/bin/wallpaper-set "$WALL"
  '';
in
{
  home.packages = [
    matugenPkg
    wallpaper-set
    wallpaper-pick
  ];

  # Matugen config
  xdg.configFile."matugen/config.toml".text = ''
    [config]
    mode = "dark"
    type = "scheme-tonal-spot"
    contrast = 0.0

    [templates.waybar-css]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/waybar.css"
    output_path = "${config.home.homeDirectory}/.config/waybar/style.css"

    [templates.waybar-css.hooks]
    post = ["bash", "-c", "pkill -SIGUSR2 waybar || true"]

    [templates.mako]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/mako"
    output_path = "${config.home.homeDirectory}/.config/mako/config"

    [templates.mako.hooks]
    post = ["bash", "-c", "makoctl reload 2>/dev/null || true"]

    [templates.fuzzel]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/fuzzel.ini"
    output_path = "${config.home.homeDirectory}/.config/fuzzel/fuzzel.ini"

    [templates.ghostty]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/ghostty"
    output_path = "${config.home.homeDirectory}/.config/ghostty/config"

    [templates.niri-colors]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/niri-colors"
    output_path = "${config.home.homeDirectory}/.config/matugen/generated/niri-colors"

    [templates.tmux-theme]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/tmux-theme.conf"
    output_path = "${config.home.homeDirectory}/.config/tmux/matugen-theme.conf"

    [templates.tmux-theme.hooks]
    post = ["bash", "-c", "tmux source-file ~/.config/tmux/matugen-theme.conf 2>/dev/null || true"]

    [templates.swaylock]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/swaylock"
    output_path = "${config.home.homeDirectory}/.config/swaylock/config"

    [templates.fzf-colors]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/fzf-colors"
    output_path = "${config.home.homeDirectory}/.config/fzf/colors"

    [templates.regreet-css]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/regreet.css"
    output_path = "/tmp/regreet-theme.css"

    [templates.starship-palette]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/starship-palette.toml"
    output_path = "${config.home.homeDirectory}/.config/matugen/generated/starship-palette.toml"
  '';

  # ── Matugen Templates ──

  # Waybar CSS template (flat glass bar)
  xdg.configFile."matugen/templates/waybar.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: rgba({{colors.surface.default.red}}, {{colors.surface.default.green}}, {{colors.surface.default.blue}}, 0.65);
      color: {{colors.on_surface.default.hex}};
      border-radius: 14px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    }

    #workspaces {
      margin: 4px 4px;
      padding: 0 4px;
    }

    #workspaces button {
      padding: 0 8px;
      color: {{colors.on_surface_variant.default.hex}};
      border: none;
      border-radius: 8px;
      margin: 2px;
      transition: all 0.2s ease;
    }

    #workspaces button:hover {
      background: rgba({{colors.primary.default.red}}, {{colors.primary.default.green}}, {{colors.primary.default.blue}}, 0.2);
      color: {{colors.on_surface.default.hex}};
    }

    #workspaces button.active {
      color: {{colors.primary.default.hex}};
      background: rgba({{colors.primary.default.red}}, {{colors.primary.default.green}}, {{colors.primary.default.blue}}, 0.25);
    }

    #cpu, #memory, #network, #pulseaudio, #bluetooth, #clock, #tray {
      padding: 0 10px;
      margin: 4px 0;
    }

    /* Subtle separator between modules */
    #cpu, #memory, #network, #pulseaudio, #bluetooth {
      border-right: 1px solid rgba(255, 255, 255, 0.06);
    }

    #cpu { color: {{colors.tertiary.default.hex}}; }
    #memory { color: {{colors.primary.default.hex}}; }
    #network { color: {{colors.secondary.default.hex}}; }
    #pulseaudio { color: {{colors.tertiary.default.hex}}; }
    #bluetooth { color: {{colors.secondary.default.hex}}; }
    #clock { color: {{colors.on_surface.default.hex}}; }
  '';

  # Mako notifications template (faux glass)
  xdg.configFile."matugen/templates/mako".text = ''
    font=JetBrainsMono Nerd Font 11
    background-color={{colors.surface.default.hex}}C8
    text-color={{colors.on_surface.default.hex}}
    border-color={{colors.outline_variant.default.hex}}80
    border-size=2
    border-radius=12
    default-timeout=5000
    padding=14
    margin=8
    width=350
    max-visible=3

    [urgency=high]
    border-color={{colors.error.default.hex}}
    default-timeout=10000
  '';

  # Fuzzel launcher template (faux glass)
  xdg.configFile."matugen/templates/fuzzel.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=14
    terminal=ghostty
    layer=overlay
    prompt=
    icon-theme=Papirus-Dark
    width=50
    lines=12
    horizontal-pad=24
    vertical-pad=16
    inner-pad=16
    letter-spacing=0.5
    use-bold=yes
    match-counter=yes
    show-actions=no
    match-mode=fzf
    placeholder=Search apps...

    [colors]
    background={{colors.surface.default.hex_stripped}}CC
    text={{colors.on_surface.default.hex_stripped}}ff
    match={{colors.primary.default.hex_stripped}}ff
    selection={{colors.surface_container.default.hex_stripped}}80
    selection-text={{colors.primary.default.hex_stripped}}ff
    selection-match={{colors.tertiary.default.hex_stripped}}ff
    border={{colors.outline_variant.default.hex_stripped}}60
    counter={{colors.on_surface_variant.default.hex_stripped}}ff
    placeholder={{colors.on_surface_variant.default.hex_stripped}}80
    prompt={{colors.primary.default.hex_stripped}}ff
    input={{colors.on_surface.default.hex_stripped}}ff

    [border]
    width=2
    radius=16
  '';

  # Ghostty terminal template
  xdg.configFile."matugen/templates/ghostty".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = {{colors.surface.default.hex}}
    foreground = {{colors.on_surface.default.hex}}

    palette = 0={{colors.surface_container.default.hex}}
    palette = 1={{colors.error.default.hex}}
    palette = 2={{colors.tertiary.default.hex}}
    palette = 3={{colors.secondary.default.hex}}
    palette = 4={{colors.primary.default.hex}}
    palette = 5={{colors.tertiary_container.default.hex}}
    palette = 6={{colors.secondary_container.default.hex}}
    palette = 7={{colors.on_surface.default.hex}}
    palette = 8={{colors.outline.default.hex}}
    palette = 9={{colors.error.default.hex}}
    palette = 10={{colors.tertiary.default.hex}}
    palette = 11={{colors.secondary.default.hex}}
    palette = 12={{colors.primary.default.hex}}
    palette = 13={{colors.tertiary_container.default.hex}}
    palette = 14={{colors.primary_container.default.hex}}
    palette = 15={{colors.on_surface.default.hex}}

    background-opacity = 0.88
    cursor-style = bar
    cursor-style-blink = true
    window-padding-x = 8
    window-padding-y = 8
    gtk-titlebar = false
    window-decoration = false
  '';

  # Niri colors template (shell-sourceable vars for wallpaper-set)
  xdg.configFile."matugen/templates/niri-colors".text = ''
    NIRI_ACTIVE_COLOR={{colors.primary.default.hex}}
    NIRI_INACTIVE_COLOR={{colors.surface_container.default.hex}}
  '';

  # Tmux matugen theme template
  xdg.configFile."matugen/templates/tmux-theme.conf".text = ''
    # Auto-generated by matugen — do not edit
    set -g status-style 'bg={{colors.surface.default.hex}},fg={{colors.on_surface.default.hex}}'
    set -g pane-border-style 'fg={{colors.surface_container.default.hex}}'
    set -g pane-active-border-style 'fg={{colors.primary.default.hex}}'
    set -g window-status-current-style 'bg={{colors.surface_container.default.hex}},fg={{colors.primary.default.hex}},bold'
    set -g window-status-style 'fg={{colors.on_surface_variant.default.hex}}'
    set -g message-style 'bg={{colors.surface.default.hex}},fg={{colors.on_surface.default.hex}}'
    set -g mode-style 'bg={{colors.surface_container.default.hex}},fg={{colors.on_surface.default.hex}}'
    set -g status-left '#[bg={{colors.primary.default.hex}},fg={{colors.surface.default.hex}},bold] #S #[default] '
    set -g status-right '#[fg={{colors.on_surface_variant.default.hex}}] %H:%M  %a %b %d '
    set -g window-status-current-format ' #I:#W '
    set -g window-status-format ' #I:#W '
  '';

  # Swaylock template (minimal indicator + heavy blur)
  xdg.configFile."matugen/templates/swaylock".text = ''
    image=~/wallpaper.png
    indicator
    indicator-radius=80
    indicator-thickness=6
    effect-blur=12x6
    effect-vignette=0.4:0.7
    grace=3
    fade-in=0.2

    font=JetBrainsMono Nerd Font

    bs-hl-color={{colors.error.default.hex_stripped}}
    key-hl-color={{colors.tertiary.default.hex_stripped}}
    separator-color=00000000
    layout-bg-color=00000000
    layout-text-color={{colors.on_surface.default.hex_stripped}}

    inside-color={{colors.surface.default.hex_stripped}}AA
    inside-clear-color={{colors.surface.default.hex_stripped}}AA
    inside-ver-color={{colors.surface.default.hex_stripped}}AA
    inside-wrong-color={{colors.surface.default.hex_stripped}}AA

    ring-color={{colors.outline.default.hex_stripped}}
    ring-clear-color={{colors.tertiary.default.hex_stripped}}
    ring-ver-color={{colors.primary.default.hex_stripped}}
    ring-wrong-color={{colors.error.default.hex_stripped}}

    line-color=00000000
    line-clear-color=00000000
    line-ver-color=00000000
    line-wrong-color=00000000

    text-color={{colors.on_surface.default.hex_stripped}}
    text-clear-color={{colors.tertiary.default.hex_stripped}}
    text-ver-color={{colors.primary.default.hex_stripped}}
    text-wrong-color={{colors.error.default.hex_stripped}}
  '';

  # fzf colors template
  xdg.configFile."matugen/templates/fzf-colors".text = ''
    --color=bg+:{{colors.surface_container.default.hex}},bg:{{colors.surface.default.hex}},spinner:{{colors.primary.default.hex}},hl:{{colors.primary.default.hex}}
    --color=fg:{{colors.on_surface.default.hex}},header:{{colors.primary.default.hex}},info:{{colors.secondary.default.hex}},pointer:{{colors.primary.default.hex}}
    --color=marker:{{colors.primary.default.hex}},fg+:{{colors.on_surface.default.hex}},prompt:{{colors.primary.default.hex}},hl+:{{colors.tertiary.default.hex}}
  '';

  # ReGreet CSS template (faux glass greeter)
  xdg.configFile."matugen/templates/regreet.css".text = ''
    window {
      background-size: cover;
      background-position: center;
    }

    .login-box {
      background-color: rgba({{colors.surface.default.red}}, {{colors.surface.default.green}}, {{colors.surface.default.blue}}, 0.55);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
    }

    entry {
      background-color: rgba({{colors.surface_container.default.red}}, {{colors.surface_container.default.green}}, {{colors.surface_container.default.blue}}, 0.3);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 12px;
      padding: 12px 16px;
      color: {{colors.on_surface.default.hex}};
    }

    button {
      background-color: rgba({{colors.primary.default.red}}, {{colors.primary.default.green}}, {{colors.primary.default.blue}}, 0.25);
      border: 1px solid rgba(255, 255, 255, 0.18);
      border-radius: 12px;
      color: {{colors.on_surface.default.hex}};
      padding: 10px 24px;
    }
  '';

  # Starship palette-only template (format strings live in shell.nix)
  xdg.configFile."matugen/templates/starship-palette.toml".text = ''
    [palettes.matugen]
    color_primary = "{{colors.primary.default.hex}}"
    color_secondary = "{{colors.secondary.default.hex}}"
    color_tertiary = "{{colors.tertiary.default.hex}}"
    color_surface = "{{colors.surface.default.hex}}"
    color_surface_container = "{{colors.surface_container.default.hex}}"
    color_on_surface = "{{colors.on_surface.default.hex}}"
    color_on_surface_variant = "{{colors.on_surface_variant.default.hex}}"
    color_error = "{{colors.error.default.hex}}"
  '';

  # Run matugen on activation to generate initial configs
  home.activation.matugen = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # Set initial wallpaper if none exists yet
    if [ ! -f "$HOME/wallpaper.png" ]; then
      cp "$HOME/wallpapers/nord-landscape.png" "$HOME/wallpaper.png" 2>/dev/null || true
    fi
    if [ -f "$HOME/wallpaper.png" ]; then
      mkdir -p "$HOME/.config/matugen/generated"
      ${matugenPkg}/bin/matugen image "$HOME/wallpaper.png" 2>/dev/null || true
      # Merge matugen-generated palette into starship.toml
      STARSHIP_BASE="$HOME/.config/starship.toml"
      STARSHIP_PALETTE="$HOME/.config/matugen/generated/starship-palette.toml"
      if [ -f "$STARSHIP_BASE" ] && [ -f "$STARSHIP_PALETTE" ]; then
        # Replace home-manager symlink with a mutable copy
        if [ -L "$STARSHIP_BASE" ]; then
          cp --remove-destination "$(readlink -f "$STARSHIP_BASE")" "$STARSHIP_BASE"
        fi
        ${pkgs.gawk}/bin/awk '
          /^\[palettes\.matugen\]/ { skip=1; next }
          /^\[/ { skip=0 }
          !skip
        ' "$STARSHIP_BASE" > "$STARSHIP_BASE.tmp" && mv "$STARSHIP_BASE.tmp" "$STARSHIP_BASE"
        echo "" >> "$STARSHIP_BASE"
        cat "$STARSHIP_PALETTE" >> "$STARSHIP_BASE"
      fi
      # Apply matugen-generated colors to niri border config
      NIRI_COLORS="$HOME/.config/matugen/generated/niri-colors"
      NIRI_CONFIG="$HOME/.config/niri/config.kdl"
      if [ -f "$NIRI_COLORS" ] && [ -f "$NIRI_CONFIG" ]; then
        source "$NIRI_COLORS"
        if [ -L "$NIRI_CONFIG" ]; then
          cp --remove-destination "$(readlink -f "$NIRI_CONFIG")" "$NIRI_CONFIG"
        fi
        ${pkgs.gnused}/bin/sed -i "s/active-color \"#[0-9A-Fa-f]\{6\}\"/active-color \"$NIRI_ACTIVE_COLOR\"/" "$NIRI_CONFIG"
        ${pkgs.gnused}/bin/sed -i "s/inactive-color \"#[0-9A-Fa-f]\{6\}\"/inactive-color \"$NIRI_INACTIVE_COLOR\"/" "$NIRI_CONFIG"
      fi
    fi
  '';
}
