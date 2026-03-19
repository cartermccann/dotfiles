# Theme registry — collects all theme definitions, generates JSON files for
# runtime switching, and provides theme-select / theme-apply scripts.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Import all theme palettes
  themes = {
    catppuccin-mocha = import ./catppuccin-mocha.nix;
    nord = import ./nord.nix;
    tokyo-night = import ./tokyo-night.nix;
    kanagawa = import ./kanagawa.nix;
    gruvbox-dark = import ./gruvbox-dark.nix;
    rose-pine = import ./rose-pine.nix;
    square = import ./square.nix;
  };

  # Convert a theme attrset to JSON for runtime scripts
  themeToJson =
    theme:
    builtins.toJSON ({
      inherit (theme)
        slug
        name
        primary
        secondary
        tertiary
        surface
        surface_container
        surface_container_high
        on_surface
        on_surface_variant
        error
        outline
        outline_variant
        on_primary_container
        on_tertiary_container
        nvim_colorscheme
        delta_theme
        bat_theme
        ;
    } // {
      border_radius = theme.border_radius or null;
      background_opacity = theme.background_opacity or null;
    });

  # ── theme-apply: non-interactive, applies a named theme everywhere ──
  theme-apply = pkgs.writeShellScriptBin "theme-apply" ''
    set -euo pipefail

    THEME="$1"
    THEME_DIR="$HOME/.config/theme/themes"
    THEME_FILE="$THEME_DIR/$THEME.json"

    if [ ! -f "$THEME_FILE" ]; then
      echo "Unknown theme: $THEME"
      echo "Available: $(ls "$THEME_DIR" | ${pkgs.gnused}/bin/sed 's/\.json$//' | tr '\n' ' ')"
      exit 1
    fi

    # Read theme colors from JSON
    get() { ${pkgs.jq}/bin/jq -r ".$1" "$THEME_FILE"; }

    PRIMARY=$(get primary)
    SECONDARY=$(get secondary)
    TERTIARY=$(get tertiary)
    SURFACE=$(get surface)
    SURFACE_CONTAINER=$(get surface_container)
    SURFACE_CONTAINER_HIGH=$(get surface_container_high)
    ON_SURFACE=$(get on_surface)
    ON_SURFACE_VARIANT=$(get on_surface_variant)
    ERROR=$(get error)
    OUTLINE=$(get outline)
    OUTLINE_VARIANT=$(get outline_variant)
    ON_PRIMARY_CONTAINER=$(get on_primary_container)
    ON_TERTIARY_CONTAINER=$(get on_tertiary_container)
    NVIM_COLORSCHEME=$(get nvim_colorscheme)
    DELTA_THEME=$(get delta_theme)
    BAT_THEME=$(get bat_theme)

    BORDER_RADIUS=$(get border_radius)
    if [ "$BORDER_RADIUS" = "null" ] || [ -z "$BORDER_RADIUS" ]; then
      MAKO_RADIUS=12
      FUZZEL_RADIUS=16
      NIRI_RADIUS=16
    else
      MAKO_RADIUS=$BORDER_RADIUS
      FUZZEL_RADIUS=$BORDER_RADIUS
      NIRI_RADIUS=$BORDER_RADIUS
    fi

    BG_OPACITY=$(get background_opacity)
    if [ "$BG_OPACITY" = "null" ] || [ -z "$BG_OPACITY" ]; then
      BG_OPACITY=1.0
    fi

    # Strip # from hex for formats that need it
    strip() { echo "$1" | ${pkgs.gnused}/bin/sed 's/^#//'; }

    mkdir -p "$HOME/.config/ghostty"
    mkdir -p "$HOME/.config/waybar"
    mkdir -p "$HOME/.config/mako"
    mkdir -p "$HOME/.config/cava"
    mkdir -p "$HOME/.config/fuzzel"
    mkdir -p "$HOME/.config/tmux"
    mkdir -p "$HOME/.config/swaylock"
    mkdir -p "$HOME/.config/fzf"
    mkdir -p "$HOME/.config/theme"
    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"

    # ── Ghostty ──
    cat > "$HOME/.config/ghostty/config" <<GHOSTTY
    font-family = JetBrainsMono Nerd Font
    font-size = 14

    background = $SURFACE
    foreground = $ON_SURFACE

    palette = 0=$SURFACE_CONTAINER
    palette = 1=$ERROR
    palette = 2=$TERTIARY
    palette = 3=$SECONDARY
    palette = 4=$PRIMARY
    palette = 5=$TERTIARY
    palette = 6=$SECONDARY
    palette = 7=$ON_SURFACE
    palette = 8=$OUTLINE
    palette = 9=$ERROR
    palette = 10=$TERTIARY
    palette = 11=$SECONDARY
    palette = 12=$PRIMARY
    palette = 13=$ON_TERTIARY_CONTAINER
    palette = 14=$ON_PRIMARY_CONTAINER
    palette = 15=$ON_SURFACE

    cursor-color = $PRIMARY
    cursor-text = $SURFACE
    selection-foreground = $SURFACE
    selection-background = $PRIMARY

    background-opacity = $BG_OPACITY
    background-blur = false
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
    GHOSTTY

    # ── Waybar CSS ──
    cat > "$HOME/.config/waybar/style.css" <<WAYBAR
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: rgba(0, 0, 0, 1.0);
      color: $ON_SURFACE_VARIANT;
      border-radius: 0;
      border-bottom: 1px solid $OUTLINE;
    }

    #workspaces {
      margin: 0;
      padding: 0 4px;
    }

    #workspaces button {
      padding: 0 8px;
      color: $OUTLINE;
      border: none;
      border-radius: 0;
      margin: 0;
    }

    #workspaces button:hover {
      background: $SURFACE_CONTAINER;
      color: $ON_SURFACE;
    }

    #workspaces button.active {
      color: $PRIMARY;
      background: $SURFACE_CONTAINER;
    }

    #cpu, #memory, #network, #pulseaudio, #bluetooth, #clock, #tray {
      padding: 0 10px;
      margin: 0;
      color: $ON_SURFACE_VARIANT;
    }

    #cpu, #memory, #network, #pulseaudio, #bluetooth {
      border-right: 1px solid $OUTLINE;
    }

    #clock { color: $ON_SURFACE; }
    WAYBAR

    pkill -SIGUSR2 waybar 2>/dev/null || true

    # ── Mako ──
    cat > "$HOME/.config/mako/config" <<MAKO
    font=JetBrainsMono Nerd Font 11
    background-color=$SURFACE
    text-color=$ON_SURFACE
    border-color=''${OUTLINE_VARIANT}80
    border-size=2
    border-radius=$MAKO_RADIUS
    default-timeout=5000
    padding=14
    margin=8
    width=350
    max-visible=3

    [urgency=high]
    border-color=$ERROR
    default-timeout=10000
    MAKO

    makoctl reload 2>/dev/null || true

    # ── Fuzzel ──
    cat > "$HOME/.config/fuzzel/fuzzel.ini" <<FUZZEL
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
    background=$(strip $SURFACE)ff
    text=$(strip $ON_SURFACE)ff
    match=$(strip $PRIMARY)ff
    selection=$(strip $SURFACE_CONTAINER)80
    selection-text=$(strip $PRIMARY)ff
    selection-match=$(strip $TERTIARY)ff
    border=$(strip $OUTLINE_VARIANT)60
    counter=$(strip $ON_SURFACE_VARIANT)ff
    placeholder=$(strip $ON_SURFACE_VARIANT)80
    prompt=$(strip $PRIMARY)ff
    input=$(strip $ON_SURFACE)ff

    [border]
    width=2
    radius=$FUZZEL_RADIUS
    FUZZEL

    # ── Tmux ──
    cat > "$HOME/.config/tmux/matugen-theme.conf" <<TMUX
    # Auto-generated by theme-apply
    set -g status-style 'bg=$SURFACE,fg=$ON_SURFACE'
    set -g pane-border-style 'fg=$SURFACE_CONTAINER'
    set -g pane-active-border-style 'fg=$PRIMARY'
    set -g window-status-current-style 'bg=$SURFACE_CONTAINER,fg=$PRIMARY,bold'
    set -g window-status-style 'fg=$ON_SURFACE_VARIANT'
    set -g message-style 'bg=$SURFACE,fg=$ON_SURFACE'
    set -g mode-style 'bg=$SURFACE_CONTAINER,fg=$ON_SURFACE'
    set -g status-left '#[bg=$PRIMARY,fg=$SURFACE,bold] #S #[default] '
    set -g status-right '#[fg=$ON_SURFACE_VARIANT] %H:%M  %a %b %d '
    set -g window-status-current-format ' #I:#W '
    set -g window-status-format ' #I:#W '
    TMUX

    tmux source-file "$HOME/.config/tmux/matugen-theme.conf" 2>/dev/null || true

    # ── Swaylock ──
    cat > "$HOME/.config/swaylock/config" <<SWAYLOCK
    image=$HOME/wallpaper.png
    effect-blur=20x3
    effect-vignette=0.3:0.8
    scaling=fill

    indicator
    indicator-radius=80
    indicator-thickness=6
    clock
    timestr=%H:%M
    datestr=%A, %B %d
    grace=3
    fade-in=0.2

    font=JetBrainsMono Nerd Font

    bs-hl-color=$(strip $OUTLINE)
    key-hl-color=$(strip $ON_SURFACE_VARIANT)
    separator-color=00000000
    layout-bg-color=00000000
    layout-text-color=$(strip $ON_SURFACE_VARIANT)

    inside-color=00000088
    inside-clear-color=00000088
    inside-ver-color=00000088
    inside-wrong-color=00000088

    ring-color=$(strip $OUTLINE)
    ring-clear-color=$(strip $OUTLINE)
    ring-ver-color=$(strip $PRIMARY)
    ring-wrong-color=$(strip $ERROR)

    line-color=00000000
    line-clear-color=00000000
    line-ver-color=00000000
    line-wrong-color=00000000

    text-color=$(strip $ON_SURFACE)
    text-clear-color=$(strip $ON_SURFACE_VARIANT)
    text-ver-color=$(strip $ON_SURFACE)
    text-wrong-color=$(strip $ERROR)
    SWAYLOCK

    # ── fzf colors ──
    cat > "$HOME/.config/fzf/colors" <<FZF
    --color=bg+:$SURFACE_CONTAINER,bg:$SURFACE,spinner:$PRIMARY,hl:$PRIMARY
    --color=fg:$ON_SURFACE,header:$PRIMARY,info:$SECONDARY,pointer:$PRIMARY
    --color=marker:$PRIMARY,fg+:$ON_SURFACE,prompt:$PRIMARY,hl+:$TERTIARY
    FZF

    # ── GTK color overrides (adw-gtk3 / libadwaita) ──
    [ -L "$HOME/.config/gtk-4.0/gtk.css" ] && rm "$HOME/.config/gtk-4.0/gtk.css"
    [ -L "$HOME/.config/gtk-3.0/gtk.css" ] && rm "$HOME/.config/gtk-3.0/gtk.css"
    cat > "$HOME/.config/gtk-4.0/gtk.css" <<GTK
    @define-color accent_bg_color $PRIMARY;
    @define-color accent_color $PRIMARY;
    @define-color accent_fg_color $SURFACE;
    @define-color window_bg_color $SURFACE;
    @define-color window_fg_color $ON_SURFACE;
    @define-color headerbar_bg_color $SURFACE_CONTAINER;
    @define-color headerbar_fg_color $ON_SURFACE;
    @define-color view_bg_color $SURFACE;
    @define-color view_fg_color $ON_SURFACE;
    @define-color card_bg_color $SURFACE_CONTAINER;
    @define-color card_fg_color $ON_SURFACE;
    @define-color sidebar_bg_color $SURFACE_CONTAINER;
    @define-color sidebar_fg_color $ON_SURFACE;
    @define-color popover_bg_color $SURFACE_CONTAINER;
    @define-color popover_fg_color $ON_SURFACE;
    @define-color dialog_bg_color $SURFACE_CONTAINER;
    @define-color dialog_fg_color $ON_SURFACE;
    @define-color destructive_bg_color $ERROR;
    @define-color borders alpha($OUTLINE, 0.5);
    GTK
    cp "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    # ── Starship palette ──
    STARSHIP_BASE="$HOME/.config/starship.toml"
    if [ -f "$STARSHIP_BASE" ]; then
      if [ -L "$STARSHIP_BASE" ]; then
        cp --remove-destination "$(readlink -f "$STARSHIP_BASE")" "$STARSHIP_BASE"
      fi
      chmod u+w "$STARSHIP_BASE" 2>/dev/null || true
      ${pkgs.gawk}/bin/awk '
        /^\[palettes\.matugen\]/ { skip=1; next }
        /^\[/ { skip=0 }
        !skip
      ' "$STARSHIP_BASE" > "$STARSHIP_BASE.tmp" && mv -f "$STARSHIP_BASE.tmp" "$STARSHIP_BASE"
      cat >> "$STARSHIP_BASE" <<STARSHIP

    [palettes.matugen]
    color_primary = "$PRIMARY"
    color_secondary = "$SECONDARY"
    color_tertiary = "$TERTIARY"
    color_surface = "$SURFACE"
    color_surface_container = "$SURFACE_CONTAINER"
    color_on_surface = "$ON_SURFACE"
    color_on_surface_variant = "$ON_SURFACE_VARIANT"
    color_error = "$ERROR"
    STARSHIP
    fi

    # ── Niri border colors ──
    NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    if [ -f "$NIRI_CONFIG" ]; then
      if [ -L "$NIRI_CONFIG" ]; then
        cp --remove-destination "$(readlink -f "$NIRI_CONFIG")" "$NIRI_CONFIG"
      fi
      chmod u+w "$NIRI_CONFIG" 2>/dev/null || true
      ${pkgs.gnused}/bin/sed -i "s/active-gradient from=\"#[0-9A-Fa-f]\{6\}\" to=\"#[0-9A-Fa-f]\{6\}\"/active-gradient from=\"$PRIMARY\" to=\"$TERTIARY\"/" "$NIRI_CONFIG"
      ${pkgs.gnused}/bin/sed -i "s/inactive-gradient from=\"#[0-9A-Fa-f]\{6\}\" to=\"#[0-9A-Fa-f]\{6\}\"/inactive-gradient from=\"$SURFACE_CONTAINER\" to=\"$OUTLINE_VARIANT\"/" "$NIRI_CONFIG"
      ${pkgs.gnused}/bin/sed -i "s/geometry-corner-radius [0-9]\+/geometry-corner-radius $NIRI_RADIUS/" "$NIRI_CONFIG"
      niri msg action reload-config 2>/dev/null || true
    fi

    # ── Delta syntax theme ──
    mkdir -p "$HOME/.config/delta"
    cat > "$HOME/.config/delta/theme" <<DELTA
    [delta]
        syntax-theme = $DELTA_THEME
    DELTA

    # ── Bat theme (persist for future shell sessions) ──
    mkdir -p "$HOME/.config/bat"
    echo "--theme=\"$BAT_THEME\"" > "$HOME/.config/bat/config"

    # ── cava audio visualizer ──
    mkdir -p "$HOME/.config/cava"
    cat > "$HOME/.config/cava/config" <<CAVA
    [general]
    framerate = 60
    bars = 0
    bar_width = 2
    bar_spacing = 1

    [input]
    method = pipewire
    source = auto

    [output]
    method = noncurses
    channels = stereo

    [color]
    gradient = 1
    gradient_count = 3
    gradient_color_1 = '$PRIMARY'
    gradient_color_2 = '$TERTIARY'
    gradient_color_3 = '$SECONDARY'

    [smoothing]
    noise_reduction = 77
    CAVA

    # ── Neovim signal ──
    # Write colorscheme name so Neovim can pick it up
    echo "$NVIM_COLORSCHEME" > "$HOME/.config/theme/nvim-colorscheme"

    # Signal all running Neovim instances to reload
    for sock in /run/user/$(id -u)/nvim.*.0 "$XDG_RUNTIME_DIR"/nvim.*.0 /tmp/nvim-*/0; do
      [ -S "$sock" ] 2>/dev/null && \
        ${pkgs.neovim}/bin/nvim --server "$sock" --remote-send '<cmd>lua pcall(require, "theme-sync")<cr>' 2>/dev/null || true
    done

    # ── Persist selection ──
    echo "$THEME" > "$HOME/.config/theme/current"

    echo "Applied theme: $(get name)"
  '';

  # ── theme-select: interactive TUI picker using gum ──
  theme-select = pkgs.writeShellScriptBin "theme-select" ''
    set -euo pipefail

    THEME_DIR="$HOME/.config/theme/themes"
    CURRENT=$(cat "$HOME/.config/theme/current" 2>/dev/null || echo "")

    # Build a simple "slug:Display Name" map
    declare -A SLUG_MAP
    CHOICES=""

    for f in "$THEME_DIR"/*.json; do
      SLUG=$(${pkgs.jq}/bin/jq -r '.slug' "$f")
      NAME=$(${pkgs.jq}/bin/jq -r '.name' "$f")

      MARKER=""
      [ "$SLUG" = "$CURRENT" ] && MARKER=" (current)"

      LABEL="$NAME$MARKER"
      SLUG_MAP["$LABEL"]="$SLUG"

      if [ -z "$CHOICES" ]; then
        CHOICES="$LABEL"
      else
        CHOICES="$CHOICES"$'\n'"$LABEL"
      fi
    done

    # Add dynamic/matugen option
    DYN_MARKER=""
    [ "$CURRENT" = "dynamic" ] && DYN_MARKER=" (current)"
    DYN_LABEL="Dynamic (wallpaper colors)$DYN_MARKER"
    SLUG_MAP["$DYN_LABEL"]="dynamic"
    CHOICES="$CHOICES"$'\n'"$DYN_LABEL"

    # Present choices
    SELECTED=$(echo "$CHOICES" | ${pkgs.gum}/bin/gum choose --header "Select Theme" --cursor.foreground="#88c0d0" --height=10) || exit 0

    SELECTED_SLUG="''${SLUG_MAP[$SELECTED]:-}"

    if [ -z "$SELECTED_SLUG" ]; then
      echo "Could not resolve selection."
      exit 1
    fi

    if [ "$SELECTED_SLUG" = "dynamic" ]; then
      echo "dynamic" > "$HOME/.config/theme/current"
      echo "Switched to dynamic mode. Use wallpaper-set to apply wallpaper colors."
      if [ -f "$HOME/wallpaper.png" ]; then
        wallpaper-set "$HOME/wallpaper.png"
      fi
      exit 0
    fi

    ${theme-apply}/bin/theme-apply "$SELECTED_SLUG"
  '';

in
{
  home.packages = [
    theme-apply
    theme-select
    pkgs.gum
  ];

  # Generate JSON theme files for runtime scripts
  xdg.configFile = lib.mapAttrs' (
    slug: theme:
    lib.nameValuePair "theme/themes/${slug}.json" {
      text = themeToJson theme;
    }
  ) themes;

  # On activation: apply named theme if one is selected
  # (matugen/dynamic fallback is handled by theme.nix)
  home.activation.applyNamedTheme = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/theme"

    CURRENT=$(cat "$HOME/.config/theme/current" 2>/dev/null || echo "")
    THEME_FILE="$HOME/.config/theme/themes/$CURRENT.json"

    if [ -n "$CURRENT" ] && [ "$CURRENT" != "dynamic" ] && [ -f "$THEME_FILE" ]; then
      ${theme-apply}/bin/theme-apply "$CURRENT" 2>/dev/null || true
    fi
  '';
}
