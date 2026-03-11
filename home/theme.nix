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
    # Copy for persistence
    cp "$WALLPAPER" ~/wallpaper.png
    # Copy for greeter (requires sudo)
    sudo cp "$WALLPAPER" /etc/greetd/wallpaper.png 2>/dev/null || true
    # Regenerate all theme configs from wallpaper colors
    ${matugenPkg}/bin/matugen image "$WALLPAPER" --mode dark
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
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/niri-colors.kdl"
    output_path = "${config.home.homeDirectory}/.config/niri/colors.kdl"

    [templates.swaylock]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/swaylock"
    output_path = "${config.home.homeDirectory}/.config/swaylock/config"

    [templates.fzf-colors]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/fzf-colors"
    output_path = "${config.home.homeDirectory}/.config/fzf/colors"

    [templates.regreet-css]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/regreet.css"
    output_path = "/tmp/regreet-theme.css"

    [templates.starship]
    input_path = "${config.home.homeDirectory}/.config/matugen/templates/starship.toml"
    output_path = "${config.home.homeDirectory}/.config/starship.toml"
  '';

  # ── Matugen Templates ──

  # Waybar CSS template (faux glass)
  xdg.configFile."matugen/templates/waybar.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: rgba({{colors.surface.default.red}}, {{colors.surface.default.green}}, {{colors.surface.default.blue}}, 0.72);
      color: {{colors.on_surface.default.hex}};
      border-radius: 14px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    }

    #workspaces {
      background: rgba({{colors.surface_container.default.red}}, {{colors.surface_container.default.green}}, {{colors.surface_container.default.blue}}, 0.85);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 10px;
      margin: 4px 2px;
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
      background: rgba({{colors.surface_container.default.red}}, {{colors.surface_container.default.green}}, {{colors.surface_container.default.blue}}, 0.85);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 10px;
      margin: 4px 2px;
      padding: 0 12px;
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

  # Niri colors KDL template
  # Note: niri include files cannot override layout {} blocks set in the main config,
  # so border colors remain in the main config. This file provides color values as
  # comments for reference; actual border colors use matugen-generated values
  # after wallpaper-set runs and are applied via the niri config directly.
  xdg.configFile."matugen/templates/niri-colors.kdl".text = ''
    // Auto-generated by matugen — do not edit
    // primary: {{colors.primary.default.hex}}
    // secondary: {{colors.secondary.default.hex}}
    // surface: {{colors.surface.default.hex}}
    // on_surface: {{colors.on_surface.default.hex}}
  '';

  # Swaylock template
  xdg.configFile."matugen/templates/swaylock".text = ''
    image=~/wallpaper.png
    clock
    indicator
    indicator-radius=120
    indicator-thickness=10
    effect-blur=7x5
    effect-vignette=0.5:0.5
    grace=3
    fade-in=0.2

    font=JetBrainsMono Nerd Font

    bs-hl-color={{colors.error.default.hex_stripped}}
    key-hl-color={{colors.tertiary.default.hex_stripped}}
    separator-color=00000000
    layout-bg-color=00000000
    layout-text-color={{colors.on_surface.default.hex_stripped}}

    inside-color={{colors.surface.default.hex_stripped}}DD
    inside-clear-color={{colors.surface.default.hex_stripped}}DD
    inside-ver-color={{colors.surface.default.hex_stripped}}DD
    inside-wrong-color={{colors.surface.default.hex_stripped}}DD

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

  # Starship prompt template
  xdg.configFile."matugen/templates/starship.toml".text = ''
    format = """
    [░▒▓]({{colors.primary.default.hex}})\
    [ ](bg:{{colors.primary.default.hex}} fg:#090c0c)\
    [](bg:{{colors.secondary.default.hex}} fg:{{colors.primary.default.hex}})\
    $directory\
    [](fg:{{colors.secondary.default.hex}} bg:{{colors.surface_container.default.hex}})\
    $git_branch\
    $git_status\
    [](fg:{{colors.surface_container.default.hex}} bg:{{colors.surface.default.hex}})\
    $nodejs\
    $rust\
    $golang\
    $php\
    [](fg:{{colors.surface.default.hex}})\
    \n$character"""

    [directory]
    format = "[ $path ]($style)"
    style = "fg:#e3e5e5 bg:{{colors.secondary.default.hex}}"
    truncation_length = 3
    truncation_symbol = "…/"

    [directory.substitutions]
    "Documents" = "󰈙 "
    "Downloads" = " "
    "Music" = " "
    "Pictures" = " "

    [git_branch]
    symbol = ""
    style = "bg:{{colors.surface_container.default.hex}}"
    format = "[[ $symbol $branch ](fg:{{colors.primary.default.hex}} bg:{{colors.surface_container.default.hex}})]($style)"

    [git_status]
    style = "bg:{{colors.surface_container.default.hex}}"
    format = "[[($all_status$ahead_behind )](fg:{{colors.primary.default.hex}} bg:{{colors.surface_container.default.hex}})]($style)"

    [nodejs]
    symbol = ""
    style = "bg:{{colors.surface.default.hex}}"
    format = "[[ $symbol ($version) ](fg:{{colors.primary.default.hex}} bg:{{colors.surface.default.hex}})]($style)"

    [rust]
    symbol = ""
    style = "bg:{{colors.surface.default.hex}}"
    format = "[[ $symbol ($version) ](fg:{{colors.primary.default.hex}} bg:{{colors.surface.default.hex}})]($style)"

    [golang]
    symbol = ""
    style = "bg:{{colors.surface.default.hex}}"
    format = "[[ $symbol ($version) ](fg:{{colors.primary.default.hex}} bg:{{colors.surface.default.hex}})]($style)"

    [php]
    symbol = ""
    style = "bg:{{colors.surface.default.hex}}"
    format = "[[ $symbol ($version) ](fg:{{colors.primary.default.hex}} bg:{{colors.surface.default.hex}})]($style)"

    [time]
    disabled = false
    time_format = "%R"
    style = "bg:{{colors.surface.default.hex}}"
    format = "[[  $time ](fg:{{colors.on_surface_variant.default.hex}} bg:{{colors.surface.default.hex}})]($style)"
  '';

  # Run matugen on activation to generate initial configs
  home.activation.matugen = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/wallpaper.png" ]; then
      ${matugenPkg}/bin/matugen image "$HOME/wallpaper.png" --mode dark 2>/dev/null || true
    fi
  '';
}
