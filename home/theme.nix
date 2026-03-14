{
  config,
  pkgs,
  user,
  matugen,
  ...
}:

let
  matugenPkg = matugen.packages.${pkgs.system}.default;

  theme-apply-colors = pkgs.writeShellScript "theme-apply-colors" ''
    # Merge matugen-generated palette into starship.toml
    STARSHIP_BASE="$HOME/.config/starship.toml"
    STARSHIP_PALETTE="$HOME/.config/matugen/generated/starship-palette.toml"
    if [ -f "$STARSHIP_BASE" ] && [ -f "$STARSHIP_PALETTE" ]; then
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
      niri msg action reload-config 2>/dev/null || true
    fi

    # Mark mode as dynamic and signal Neovim
    echo "dynamic" > "$HOME/.config/theme/current"
  '';

  wallpaper-set = pkgs.writeShellScriptBin "wallpaper-set" ''
    WALLPAPER="$1"
    if [ -z "$WALLPAPER" ]; then
      echo "Usage: wallpaper-set <image-path>"
      exit 1
    fi
    ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type grow --transition-duration 1.5
    [ -L ~/wallpaper.png ] && rm ~/wallpaper.png
    cp -f "$WALLPAPER" ~/wallpaper.png
    mkdir -p "$HOME/.config/matugen/generated"
    mkdir -p "$HOME/.config/theme"
    ${matugenPkg}/bin/matugen image "$WALLPAPER" --source-color-index 0
    ${theme-apply-colors}
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

  # Matugen config (used when in "dynamic" mode)
  xdg.configFile."matugen/config.toml".text = ''
    [config]
    mode = "dark"
    type = "scheme-tonal-spot"
    contrast = 0.5

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

    [templates.starship-palette]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/starship-palette.toml"
    output_path = "${config.home.homeDirectory}/.config/matugen/generated/starship-palette.toml"
  '';

  # ── Matugen Templates (used in dynamic mode) ──

  # Waybar CSS template
  xdg.configFile."matugen/templates/waybar.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: rgba(0, 0, 0, 0.85);
      color: #AAAAAA;
      border-radius: 0;
      border-bottom: 1px solid #555555;
    }

    #workspaces {
      margin: 0;
      padding: 0 4px;
    }

    #workspaces button {
      padding: 0 8px;
      color: #888888;
      border: none;
      border-radius: 0;
      margin: 0;
    }

    #workspaces button:hover {
      background: #333333;
      color: #CCCCCC;
    }

    #workspaces button.active {
      color: #FFFFFF;
      background: #333333;
    }

    #cpu, #memory, #network, #pulseaudio, #bluetooth, #clock, #tray {
      padding: 0 10px;
      margin: 0;
      color: #AAAAAA;
    }

    #cpu, #memory, #network, #pulseaudio, #bluetooth {
      border-right: 1px solid #555555;
    }

    #clock { color: #CCCCCC; }
  '';

  # Mako notifications template
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

  # Fuzzel launcher template
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
    palette = 5={{colors.tertiary.default.hex}}
    palette = 6={{colors.secondary.default.hex}}
    palette = 7={{colors.on_surface.default.hex}}
    palette = 8={{colors.outline.default.hex}}
    palette = 9={{colors.error.default.hex}}
    palette = 10={{colors.tertiary.default.hex}}
    palette = 11={{colors.secondary.default.hex}}
    palette = 12={{colors.primary.default.hex}}
    palette = 13={{colors.on_tertiary_container.default.hex}}
    palette = 14={{colors.on_primary_container.default.hex}}
    palette = 15={{colors.on_surface.default.hex}}

    cursor-color = {{colors.primary.default.hex}}
    cursor-text = {{colors.surface.default.hex}}
    selection-foreground = {{colors.surface.default.hex}}
    selection-background = {{colors.primary.default.hex}}

    background-opacity = 0.88
    background-blur = true
    cursor-style = bar
    cursor-style-blink = true
    adjust-cell-height = 2
    font-thicken = true
    bold-is-bright = false
    mouse-hide-while-typing = true
    clipboard-trim-trailing-spaces = true
    window-padding-x = 8
    window-padding-y = 8
    window-padding-balance = true
    gtk-titlebar = false
    window-decoration = false
    notify-on-command-finish = unfocused
    notify-on-command-finish-after = 10s
  '';

  # Niri colors template
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

  # Swaylock template
  xdg.configFile."matugen/templates/swaylock".text = ''
    color=000000
    indicator
    indicator-radius=80
    indicator-thickness=6
    clock
    timestr=%H:%M
    datestr=%A, %B %d
    grace=3
    fade-in=0.2

    font=JetBrainsMono Nerd Font

    bs-hl-color=888888
    key-hl-color=AAAAAA
    separator-color=00000000
    layout-bg-color=00000000
    layout-text-color=AAAAAA

    inside-color=000000AA
    inside-clear-color=000000AA
    inside-ver-color=000000AA
    inside-wrong-color=000000AA

    ring-color=555555
    ring-clear-color=555555
    ring-ver-color=AAAAAA
    ring-wrong-color=884444

    line-color=00000000
    line-clear-color=00000000
    line-ver-color=00000000
    line-wrong-color=00000000

    text-color=AAAAAA
    text-clear-color=AAAAAA
    text-ver-color=CCCCCC
    text-wrong-color=AA4444
  '';

  # fzf colors template
  xdg.configFile."matugen/templates/fzf-colors".text = ''
    --color=bg+:{{colors.surface_container.default.hex}},bg:{{colors.surface.default.hex}},spinner:{{colors.primary.default.hex}},hl:{{colors.primary.default.hex}}
    --color=fg:{{colors.on_surface.default.hex}},header:{{colors.primary.default.hex}},info:{{colors.secondary.default.hex}},pointer:{{colors.primary.default.hex}}
    --color=marker:{{colors.primary.default.hex}},fg+:{{colors.on_surface.default.hex}},prompt:{{colors.primary.default.hex}},hl+:{{colors.tertiary.default.hex}}
  '';

  # Starship palette-only template
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

  # Clean stale HM backup files before link checking
  home.activation.cleanHmBackups = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.config/starship.toml.hm-bak"
    rm -f "$HOME/.config/niri/config.kdl.hm-bak"
  '';

  # On activation: apply matugen if in dynamic mode or first run
  # Named theme activation is handled by themes/default.nix (where theme-apply is in scope)
  home.activation.applyThemeFallback = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/theme"
    mkdir -p "$HOME/.config/matugen/generated"

    CURRENT=$(cat "$HOME/.config/theme/current" 2>/dev/null || echo "")

    # Only run matugen if in dynamic mode or no theme set yet
    if [ -z "$CURRENT" ] || [ "$CURRENT" = "dynamic" ]; then
      if [ ! -f "$HOME/wallpaper.png" ]; then
        cp "$HOME/wallpapers/nord-landscape.png" "$HOME/wallpaper.png" 2>/dev/null || true
      fi
      if [ -f "$HOME/wallpaper.png" ]; then
        ${matugenPkg}/bin/matugen image "$HOME/wallpaper.png" 2>/dev/null || true
        ${theme-apply-colors}
      fi
    fi
  '';
}
