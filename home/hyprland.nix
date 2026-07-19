{
  config,
  lib,
  pkgs,
  options,
  user,
  hyprland,
  ...
}:
let
  pal = import ../lib/palette.nix;
  cfgHome = config.xdg.configHome;

  # "#1b1917" -> "27, 25, 23" for CSS rgba(). Single palette source of truth:
  # every color literal in this file is interpolated from `pal` — one accent
  # change in lib/palette.nix re-themes the whole session.
  cssRgb =
    hex:
    let
      h = lib.removePrefix "#" hex;
    in
    lib.concatStringsSep ", " (
      map (i: toString (lib.fromHexString (builtins.substring i 2 h))) [
        0
        2
        4
      ]
    );

  # hyprctl from the same 0.55.x flake build the compositor runs, so the IPC
  # protocol matches. In 0.55, `hyprctl dispatch` takes the Lua dispatcher form.
  hyprctl = "${hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland}/bin/hyprctl";

  # this module owns the default waybar config (~/.config/waybar/{config,style.css}),
  # so launch it bare — no -c/-s needed.
  waybarCmd = "waybar";

  # Power menu (Hyprland variant of the niri power-menu — uses hyprlock + hyprctl)
  hyprPowerMenu = pkgs.writeShellScriptBin "hypr-power-menu" ''
    CHOICE=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini --prompt="⏻  ")
    case "$CHOICE" in
      Lock)     ${pkgs.hyprlock}/bin/hyprlock ;;
      Logout)   ${hyprctl} dispatch 'hl.dsp.exit()' ;;
      Suspend)  systemctl suspend ;;
      Reboot)   systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
    esac
  '';

  # Wallpaper picker (mirrors niri's; `find -L` is required for the nix-symlinked ~/wallpapers).
  # ~/wallpaper.png is a CROSS-SESSION contract (niri autostart, hyprlock background, both
  # pickers) — `magick` writes real PNG bytes there regardless of the source format, so
  # hyprlock and the niri session never see JPEG-bytes-named-png.
  hyprWallpaperPick = pkgs.writeShellScriptBin "hypr-wallpaper-pick" ''
    PICK=$(find -L ~/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
      | ${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini --prompt="Wallpaper: ")
    [ -n "$PICK" ] || exit 0
    ${pkgs.imagemagick}/bin/magick "$PICK" ~/wallpaper.png
    # Grow the new wallpaper out from the cursor; fall back to 0,0 when invoked
    # outside Hyprland (the script is niri-safe by construction).
    POS=$(${hyprctl} cursorpos 2>/dev/null | tr -d ' ')
    [ -n "$POS" ] || POS="0,0"
    ${pkgs.swww}/bin/swww img ~/wallpaper.png \
      --transition-type grow --transition-pos "$POS" \
      --transition-fps 165 --transition-duration 0.7 --transition-bezier .05,.7,.1,1
  '';

  # Night-light toggle via hyprsunset's hyprctl IPC (replaces the wlsunset pkill dance)
  hyprNightToggle = pkgs.writeShellScriptBin "hypr-night-toggle" ''
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/.hypr-night-on"
    if [ -f "$STATE" ]; then
      ${hyprctl} hyprsunset identity && rm -f "$STATE"
    else
      ${hyprctl} hyprsunset temperature 3500 && touch "$STATE"
    fi
  '';

  mkHyprlandLua = shellKind: ''
    -- Hyprland session (Hyprland 0.55+ Lua config)

    local mod = "SUPER"

    -- Monitors
    -- Dell U2414H portrait on the left, HP 27mq landscape to its right.
    -- Dell rotated 90° → occupies 1080x1920, so the HP starts at x=1080.
    hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "0x0", scale = 1, transform = 3 })
    hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60", position = "1080x0", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- Environment
    -- NVIDIA GBM_BACKEND/__GLX_VENDOR_LIBRARY_NAME etc. are already global
    -- (modules/nvidia.nix → environment.sessionVariables); only cursor sizes here.
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")

    -- Core options
    hl.config({
      cursor = {
        no_hardware_cursors = 1, -- int in 0.55 (1 = never use hw cursors)
      },
      general = {
        gaps_in = 6,
        gaps_out = 12,
        -- Japandi hairline: 1px, near-invisible. The pane is defined by its
        -- glass + shadow, not its outline; focus reads from the azure glow below.
        border_size = 1,
        ["col.active_border"] = "rgba(${pal.raw.base07}50)",
        ["col.inactive_border"] = "rgba(${pal.raw.base07}0d)",
        layout = "dwindle",
        allow_tearing = false,
        resize_on_border = true,
      },
      dwindle = {
        -- `pseudotile` is no longer a dwindle config option in 0.55 — it's a
        -- per-window state via the `pseudo` dispatcher (bound to SUPER+P below).
        preserve_split = true,
      },
      binds = {
        scroll_event_delay = 0, -- no artificial latency on scroll binds
      },
      -- Glassy blur + rounding + soft shadows + glow
      decoration = {
        rounding = 14,
        rounding_power = 2.5, -- subtle squircle — smoother corner flow than pure circle
        -- Opacity strategy: globals stay 1.0; translucency is granted per-app via
        -- window rules below (the terminal is the only glass pane by default).
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1.0,
        dim_inactive = true,
        dim_strength = 0.08, -- carries more focus signal now that borders are hairlines
        blur = {
          enabled = true,
          size = 12, -- heavy frost; drop back toward 6/3 if the GPU runs hot
          passes = 4,
          new_optimizations = true,
          ${
            if shellKind == "qs" then
              "xray = false, -- xray breaks layer-shell blur in this build; qs-shell is glass-first (bar/popouts are layers) so it pays full blur"
            else
              "xray = true, -- biggest NVIDIA perf lever: blur samples the wallpaper, not stacked windows"
          }
          ignore_opacity = true,
          noise = 0.055, -- coarser grain = the diffusion through the frost
          contrast = 0.9,
          brightness = 0.85, -- darkened backdrop = contrast for the cream type
          vibrancy = 0.25,
          vibrancy_darkness = 0.0,
          popups = true, -- blurred right-click menus
          popups_ignorealpha = 0.2,
          special = false, -- expensive; scratchpad gets opacity instead
        },
        shadow = {
          enabled = true,
          range = 20, -- big radius, fast falloff = "lifted pane"
          render_power = 4,
          color = "rgba(00000033)", -- heavy shadow kills glass; keep it soft
          color_inactive = "rgba(0000001a)",
          offset = { 0, 4 }, -- light from above
        },
        -- Inner glow (new in 0.55): light-through-glass edge on the active pane.
        -- With the border reduced to a hairline this IS the focus indicator,
        -- so it breathes a little wider/brighter than before.
        glow = {
          enabled = true,
          range = 12,
          render_power = 3,
          color = "rgba(${pal.raw.base0D}30)", -- soft azure halo
          color_inactive = "rgba(00000000)",
        },
      },
      animations = {
        enabled = true,
      },
      input = {
        kb_layout = "us",
        -- kb_options = "caps:escape", -- opt-in: uncomment to map CapsLock→Esc (vim hands)
        repeat_delay = 250,
        repeat_rate = 40, -- snappy held-key repeat for vim motions
        accel_profile = "flat", -- desktop mouse: no accel
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
          natural_scroll = true,
          tap_to_click = true, -- 0.55 lua name (was `tap-to-click` in hyprlang)
        },
      },
      gestures = {
        workspace_swipe_distance = 300,
      },
      misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
        -- `vfr` moved to debug.vfr in newer versions and defaults to true; dropped.
      },
      xwayland = {
        force_zero_scaling = true, -- no blurry XWayland on scaled outputs
      },
      ecosystem = {
        no_update_news = true,
      },
    })

    -- Animation curves + tree
    -- Philosophy: decel-heavy In, fast-linear Out, In > Out asymmetry, spring for
    -- windows, nothing over 4.5ds. (1ds = 100ms)
    hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 },  { 0.1, 1 }    } }) -- MD3 decel (scratchpad drop-in)
    hl.curve("menuDecel",       { type = "bezier", points = { { 0.1, 1 },     { 0, 1 }      } }) -- instant-feel layer fades
    hl.curve("menuAccel",       { type = "bezier", points = { { 0.52, 0.03 }, { 0.72, 0.08 } } }) -- layer exit
    hl.curve("almostLinear",    { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 }   } }) -- upstream fade default
    -- House easing tokens (reveal / snap / stage).
    hl.curve("easeReveal", { type = "bezier", points = { { 0.19, 1 },    { 0.22, 1 }  } }) -- --ease-reveal: aggressive expo-like decel
    hl.curve("easeSnap",   { type = "bezier", points = { { 0.65, 0.05 }, { 0, 1 }     } }) -- --ease-snap: late accel, hard settle
    hl.curve("easeStage",  { type = "bezier", points = { { 0.77, 0 },    { 0.175, 1 } } }) -- --ease-stage: deliberate in-out
    -- Upstream default spring, near-critically damped.
    hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

    hl.animation({ leaf = "windows",     enabled = true, speed = 3.5, spring = "easy" })
    hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3,   bezier = "easeReveal", style = "popin 85%" })
    hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.8, bezier = "almostLinear", style = "popin 90%" }) -- close gets out of the way
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 3,   bezier = "easeSnap",   style = "slide" })
    hl.animation({ leaf = "border",      enabled = true, speed = 3,   bezier = "easeReveal" })
    hl.animation({ leaf = "fade",        enabled = true, speed = 2,   bezier = "almostLinear" })
    hl.animation({ leaf = "fadeIn",      enabled = true, speed = 1.7, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut",     enabled = true, speed = 1.5, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeDim",     enabled = true, speed = 2,   bezier = "almostLinear" })
    -- Layers: bar / fuzzel / swaync / swayosd get real entrances instead of defaults.
    hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.5, bezier = "easeReveal", style = "popin 93%" })
    hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "menuAccel",       style = "popin 94%" })
    hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.6, bezier = "menuDecel" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8, bezier = "menuAccel" })
    -- Workspaces: the site's "stage transition" in-out — deliberate, cinematic slide.
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeStage", style = "slide" })
    -- Scratchpad drop-in/out (see SUPER+grave below).
    hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidefadevert 15%" })
    hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.5, bezier = "menuAccel",       style = "slidefadevert 15%" })
    -- NOTE: never add `borderangle` with style="loop" — it forces full-refresh-rate
    -- rendering permanently (~2x idle power on NVIDIA).

    -- Touchpad gesture: 3-finger horizontal swipe switches workspace
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

    -- Layer rules: frost the bar / launcher / notifications / OSD
    -- ignore_alpha sits just below each surface's CSS alpha so fully-transparent
    -- gaps (between waybar pills, around fuzzel) don't haze.
    ${
      if shellKind == "waybar" then
        lib.concatStringsSep "\n" [
          ''hl.layer_rule({ match = { namespace = "waybar" },                     blur = true, ignore_alpha = 0.2 })''
          ''hl.layer_rule({ match = { namespace = "launcher" },                   blur = true, ignore_alpha = 0.5, dim_around = true }) -- fuzzel: spotlight dim''
          ''hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true, ignore_alpha = 0.5 })''
          ''hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.5 })''
          ''hl.layer_rule({ match = { namespace = "swayosd" },                    blur = true, ignore_alpha = 0.4 })''
        ]
      else
        lib.concatStringsSep "\n" [
          ''hl.layer_rule({ match = { namespace = "launcher" },                   blur = true, ignore_alpha = 0.5, dim_around = true }) -- fuzzel: spotlight dim''
          ''hl.layer_rule({ match = { namespace = "qs-shell" }, blur = true, ignore_alpha = 0.35, blur_popups = true })''
        ]
    }

    -- Window rules
    -- The terminal is the glass centerpiece. Ghostty owns its background alpha
    -- (home/ghostty.nix) so glyphs stay fully opaque over the frost; this rule
    -- only adds the inactive dim step on top.
    hl.window_rule({ match = { class = "^(com.mitchellh.ghostty)$" }, opacity = "1.0 0.94" })
    -- Content surfaces: opaque + unblurred (readability + perf; no video shimmer).
    hl.window_rule({ match = { class = "^(firefox|chromium|zen|Brave-browser)$" }, opacity = "1.0 override 1.0 override" })
    hl.window_rule({ match = { class = "^(mpv|vlc|imv)$" }, opaque = true, no_blur = true })
    -- Video shouldn't lock the screen mid-movie (hypridle fires at 300s otherwise).
    hl.window_rule({ match = { class = "^(mpv|vlc)$" }, idle_inhibit = "always" })
    hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })
    -- Floats get deterministic geometry. Keep BOTH pavucontrol class patterns until
    -- `hyprctl clients` confirms which one the packaged build reports.
    hl.window_rule({ match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" }, float = true, size = "900 600", center = true })
    hl.window_rule({ match = { class = "^(TUI.float)$" }, float = true, size = "1100 700", center = true })
    hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
    hl.window_rule({ match = { title = "^(Open File|Save File|File Upload)" }, float = true, center = true })
    -- XWayland legacy junk: no shadow artifacts on undecorated floats.
    hl.window_rule({ match = { xwayland = true, float = true }, no_shadow = true })
    -- Scratchpad: slightly translucent so it reads as an overlay.
    hl.window_rule({ match = { workspace = "special:scratch" }, opacity = "0.92 0.92" })
    hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

    -- Keybinds
    -- Programs
    hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("ghostty"))
    -- canonical tmux session ("work"), same bind as the niri session
    hl.bind(mod .. " + ALT + RETURN", hl.dsp.exec_cmd("ghostty -e fish -c 'tmux attach; or tmux new -s work'"))
    ${
      if shellKind == "waybar" then
        ''hl.bind(mod .. " + SPACE",  hl.dsp.exec_cmd("fuzzel --config ${cfgHome}/fuzzel/hypr.ini"))''
      else
        # qs-shell's own launcher (M4): scrim + app search + calc/run
        # fallback. fuzzel stays for dmenu scripts (power-menu/cliphist/
        # wallpaper) until M7 — only the app-launcher bind itself flips.
        ''hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("qs -c qs-shell ipc call launcher toggle"))''
    }
    ${
      if shellKind == "waybar" then
        ''hl.bind(mod .. " + V",      hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini | cliphist decode | wl-copy"))''
      else
        # M7: qs-shell's own clipboard + emoji overlays (the emoji bind is a
        # qs-only ADDITION — the waybar session never had one); the fuzzel
        # dmenu clipboard pipeline stays on the waybar side.
        lib.concatStringsSep "\n" [
          ''hl.bind(mod .. " + V",      hl.dsp.exec_cmd("qs -c qs-shell ipc call clipboard toggle"))''
          ''hl.bind(mod .. " + period", hl.dsp.exec_cmd("qs -c qs-shell ipc call emoji toggle"))''
        ]
    }

    -- Screenshots (grimblast adds --freeze: the screen stops while you aim)
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd([[grimblast --freeze save area - | satty -f - --output-filename ~/Pictures/Screenshots/satty-$(date +%Y%m%d-%H%M%S).png]]))
    hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("grimblast --freeze copy output"))
    hl.bind("Print",               hl.dsp.exec_cmd([[grimblast save output ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png]]))

    -- Color picker → clipboard
    hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

    -- Window management
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + W", hl.dsp.window.close())
    hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" })) -- maximize (keep gaps/bar)
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- true fullscreen
    hl.bind(mod .. " + T", hl.dsp.window.float())
    hl.bind(mod .. " + C", hl.dsp.window.center())
    hl.bind(mod .. " + P", hl.dsp.window.pseudo())
    hl.bind(mod .. " + S", hl.dsp.layout("togglesplit")) -- dwindle layout message

    -- Scratchpad (special workspace) — drops in with slidefadevert; keep a
    -- persistent ghostty+tmux session here.
    hl.bind(mod .. " + grave",         hl.dsp.workspace.toggle_special({ name = "scratch" }))
    hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

    -- Vim + arrow focus
    hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
    hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
    hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
    hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
    hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "l" }))
    hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "d" }))
    hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "u" }))
    hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))

    -- Vim + arrow move
    hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
    hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
    hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
    hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
    hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
    hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))
    hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
    hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

    -- Resize: numeric pixel deltas (x/y).
    hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
    hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100,  y = 0, relative = true }))

    -- tmux prefix mode: SUPER+A ≈ C-a (mirrors home/tmux.nix)
    -- One-shot like tmux: each action drops back to the root keymap.
    -- Resize (SHIFT+HJKL) repeats and stays in the mode, like tmux `bind -r`;
    -- catchall swallows unknown keys and exits, so a mistyped prefix command
    -- never leaks into the focused app. Waybar shows the mode while active.
    local function oneshot(...)
      local ds = { ... }
      return function()
        for _, d in ipairs(ds) do hl.dispatch(d) end
        hl.dispatch(hl.dsp.submap("reset"))
      end
    end
    hl.define_submap("tmux", function()
      -- prefix | / - : preselect the dwindle direction, spawn the terminal there
      hl.bind("backslash",         oneshot(hl.dsp.layout("preselect r"), hl.dsp.exec_cmd("ghostty")))
      hl.bind("SHIFT + backslash", oneshot(hl.dsp.layout("preselect r"), hl.dsp.exec_cmd("ghostty")))
      hl.bind("minus",             oneshot(hl.dsp.layout("preselect d"), hl.dsp.exec_cmd("ghostty")))
      -- prefix c : new "window" → first empty workspace + terminal
      hl.bind("C", oneshot(hl.dsp.focus({ workspace = "empty" }), hl.dsp.exec_cmd("ghostty")))
      -- prefix hjkl : pane navigation
      hl.bind("H", oneshot(hl.dsp.focus({ direction = "l" })))
      hl.bind("J", oneshot(hl.dsp.focus({ direction = "d" })))
      hl.bind("K", oneshot(hl.dsp.focus({ direction = "u" })))
      hl.bind("L", oneshot(hl.dsp.focus({ direction = "r" })))
      -- prefix HJKL : repeatable resize (stays in the mode; ESC to leave)
      hl.bind("SHIFT + H", hl.dsp.window.resize({ x = -80, y = 0,   relative = true }), { repeating = true })
      hl.bind("SHIFT + J", hl.dsp.window.resize({ x = 0,   y = 80,  relative = true }), { repeating = true })
      hl.bind("SHIFT + K", hl.dsp.window.resize({ x = 0,   y = -80, relative = true }), { repeating = true })
      hl.bind("SHIFT + L", hl.dsp.window.resize({ x = 80,  y = 0,   relative = true }), { repeating = true })
      -- prefix z / x : zoom pane, kill pane
      hl.bind("Z", oneshot(hl.dsp.window.fullscreen({ mode = "maximized" })))
      hl.bind("X", oneshot(hl.dsp.window.close()))
      -- prefix n / p : next / previous "window" (workspace)
      hl.bind("N", oneshot(hl.dsp.focus({ workspace = "e+1" })))
      hl.bind("P", oneshot(hl.dsp.focus({ workspace = "e-1" })))
      -- prefix 1-9,0 : jump to workspace N (tmux select-window parity)
      for i = 1, 10 do
        local key = (i == 10) and "0" or tostring(i)
        hl.bind(key, oneshot(hl.dsp.focus({ workspace = i })))
      end
      hl.bind("ESCAPE", hl.dsp.submap("reset"))
      hl.bind("catchall", hl.dsp.submap("reset"))
    end)
    hl.bind(mod .. " + A", hl.dsp.submap("tmux"))

    -- Workspaces 1-10 (focus + move-window-to)
    for i = 1, 10 do
      local key = (i == 10) and "0" or tostring(i)
      hl.bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
      hl.bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i, follow = true }))
    end
    hl.bind(mod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

    -- Notifications (swaync)
    ${
      if shellKind == "waybar" then
        lib.concatStringsSep "\n" [
          ''hl.bind(mod .. " + comma",         hl.dsp.exec_cmd("swaync-client -d -sw")) -- dismiss latest''
          ''hl.bind(mod .. " + SHIFT + comma", hl.dsp.exec_cmd("swaync-client -C -sw")) -- close all''
          ''hl.bind(mod .. " + N",             hl.dsp.exec_cmd("swaync-client -t -sw")) -- toggle panel''
        ]
      else
        # qs-shell IPC instead — the "notifs" handler lands alongside the
        # notification center, a parallel M3 lane.
        lib.concatStringsSep "\n" [
          ''hl.bind(mod .. " + comma",         hl.dsp.exec_cmd("qs -c qs-shell ipc call notifs dismiss"))  -- dismiss latest''
          ''hl.bind(mod .. " + SHIFT + comma", hl.dsp.exec_cmd("qs -c qs-shell ipc call notifs clearAll")) -- close all''
          ''hl.bind(mod .. " + N",             hl.dsp.exec_cmd("qs -c qs-shell ipc call popout toggle notifications")) -- toggle panel''
        ]
    }

    -- Control panels
    hl.bind(mod .. " + CTRL + A", hl.dsp.exec_cmd("pavucontrol"))
    hl.bind(mod .. " + CTRL + B", hl.dsp.exec_cmd("ghostty --class=TUI.float -e bluetui"))
    hl.bind(mod .. " + CTRL + T", hl.dsp.exec_cmd("ghostty -e btop"))
    hl.bind(mod .. " + CTRL + D", hl.dsp.exec_cmd("ghostty -e rice-dashboard"))

    -- Utilities
    hl.bind(mod .. " + CTRL + L",  hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mod .. " + SHIFT + X", hl.dsp.exec_cmd("hypr-power-menu"))
    ${
      if shellKind == "waybar" then
        ''hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("hypr-wallpaper-pick"))''
      else
        # M7: qs-shell's own wallpaper picker overlay (ipc target
        # "wallpaper"). It runs the same magick → swww pipeline as
        # hypr-wallpaper-pick, writing the ~/wallpaper.png cross-session
        # contract; the fuzzel dmenu script stays on the waybar variant.
        ''hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -c qs-shell ipc call wallpaper toggle"))''
    }
    ${
      if shellKind == "waybar" then
        # Waybar handles SIGUSR2 as an in-process reload, avoiding a layer-shell
        # teardown/recreate flash. Start it only when no process is running.
        ''hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.exec_cmd("pkill -USR2 -x waybar || ${waybarCmd}"))''
      else
        # A restart, not a kill/start toggle — the shell should never stay dead
        # after one press. NB: the running process is `quickshell -c qs-shell`
        # (`qs` is just a launcher), so a pkill pattern containing 'qs -c'
        # never matches and silently no-ops.
        ''hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.exec_cmd([[bash -c "pkill -f 'quickshell -c qs-shell'; sleep 0.3; exec qs -c qs-shell"]]))''
    }
    hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
    hl.bind(mod .. " + CTRL + N",  hl.dsp.exec_cmd("hypr-night-toggle"))
    hl.bind(mod .. " + ALT + L",   hl.dsp.exec_cmd("~/.local/bin/toggle-dictation.sh"))

    -- Session
    hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

    -- Repeating volume/brightness (via swayosd for the OSD)
    ${
      if shellKind == "waybar" then
        lib.concatStringsSep "\n" [
          ''hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { repeating = true })''
          ''hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { repeating = true })''
        ]
      else
        # qs-shell's own IPC + OSD instead of swayosd.
        lib.concatStringsSep "\n" [
          ''hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs -c qs-shell ipc call audio up"),   { repeating = true })''
          ''hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs -c qs-shell ipc call audio down"), { repeating = true })''
        ]
    }
    hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("swayosd-client --brightness raise"),    { repeating = true })
    hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("swayosd-client --brightness lower"),    { repeating = true })

    -- Locked binds (work while the lock screen is active)
    ${
      if shellKind == "waybar" then
        lib.concatStringsSep "\n" [
          ''hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })''
          ''hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })''
        ]
      else
        # Output mute -> qs-shell IPC. Mic-mute: swaync/swayosd's client is
        # otherwise inert in the qs session (no swayosd-server running
        # there); wpctl works standalone and needs no OSD, so mic-mute flips
        # for real here instead of staying a dead bind.
        lib.concatStringsSep "\n" [
          ''hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("qs -c qs-shell ipc call audio mute"), { locked = true })''
          ''hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })''
        ]
    }
    hl.bind("XF86AudioPlay",    hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioNext",    hl.dsp.exec_cmd("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPrev",    hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

    -- Mouse drag/resize
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Autostart
    hl.on("hyprland.start", function()
      -- Import env into systemd/dbus, then bounce the portals (mirrors the niri startup line)
      hl.exec_cmd([[bash -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE NIXOS_OZONE_WL GBM_BACKEND NVD_BACKEND LIBVA_DRIVER_NAME __GLX_VENDOR_LIBRARY_NAME && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal 2>/dev/null']])
      hl.exec_cmd("swww-daemon")
      -- Give the daemon a moment to bind its socket, then restore the shared
      -- still wallpaper used by Niri, Hyprland, and hyprlock.
      hl.exec_cmd([[bash -c 'sleep 1 && ${pkgs.swww}/bin/swww img ${config.home.homeDirectory}/wallpaper.png --transition-type fade --transition-duration 1']])
      hl.exec_cmd("wl-paste --watch cliphist store")
      ${
        if shellKind == "waybar" then
          lib.concatStringsSep "\n  " [
            ''hl.exec_cmd("swayosd-server --style ${cfgHome}/swayosd/style.css")''
            ''hl.exec_cmd("${waybarCmd}")''
            ''hl.exec_cmd("swaync")''
          ]
        else
          # M7: hyprpolkitagent rides along — quickshell 0.2.1 has no polkit
          # QML API, so the QS session needs a standalone auth agent (the
          # waybar session keeps whatever it had; this is qs-only). Plain
          # autostart = session-scoped by construction, same as hyprsunset.
          lib.concatStringsSep "\n  " [
            ''hl.exec_cmd("qs -c qs-shell")''
            ''hl.exec_cmd("${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent")''
          ]
      }
      hl.exec_cmd("hypridle")
      -- hyprsunset as a plain autostart = hyprland-session-only by construction
      -- (a systemd user service would leak into the niri session and fight wlsunset).
      hl.exec_cmd("hyprsunset")
    end)
  '';
in
{
  config = lib.mkMerge [
    {
      home.packages = [
        hyprPowerMenu
        hyprWallpaperPick
        hyprNightToggle
        pkgs.hyprsunset # night light daemon (autostarted below; hyprland session only)
        pkgs.grimblast # screenshot wrapper (adds --freeze; wraps grim+slurp)
        pkgs.hyprpicker # color picker → clipboard (SUPER+SHIFT+C)
      ];

      # Print-screen target must exist or grimblast silently fails.
      home.file."Pictures/Screenshots/.keep".text = "";

      # Seed ~/wallpaper.png on first activation — *converted*, not copied, so the
      # PNG-named file actually contains PNG bytes (hyprlock requires it).
      home.activation.seedWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        [ -f "$HOME/wallpaper.png" ] || run ${pkgs.imagemagick}/bin/magick ${../wallpaper/fam.jpg} "$HOME/wallpaper.png"
      '';

      # Hyprland 0.55 dropped hyprlang in favor of Lua (`~/.config/hypr/hyprland.lua`).
      # The home-manager `wayland.windowManager.hyprland` module only emits the old
      # hyprlang `.conf` (which 0.55 ignores), so we bypass it and write the Lua
      # config directly. The compositor + portal come from modules/desktop-hyprland.nix.
      # API reference: $hyprland/share/hypr/stubs/hl.meta.lua
      xdg.configFile."hypr/hyprland.lua".text = mkHyprlandLua "waybar";
      xdg.configFile."hypr/hyprland-qs.lua".text = mkHyprlandLua "qs";

      # hyprsunset: scheduled night light (config read by the autostart daemon)
      xdg.configFile."hypr/hyprsunset.conf".text = ''
        profile {
            time = 6:30
            identity = true
        }

        profile {
            time = 20:30
            temperature = 3500
        }
      '';

      # Waybar: this module owns ~/.config/waybar/{config,style.css}; disable the Stylix
      # waybar target so the two never fight over style.css.
      stylix.targets.waybar.enable = false;

      xdg.configFile."waybar/config".text = builtins.toJSON {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 6;
        margin-top = 8;
        margin-left = 12;
        margin-right = 12;
        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "mpris"
          "idle_inhibitor"
          "custom/gpu"
          "cpu"
          "memory"
          "network"
          "bluetooth"
          "pulseaudio"
          "custom/notifications"
          "tray"
          "custom/power"
        ];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          all-outputs = true;
        };
        # Visible only while a submap is active (tmux prefix mode) — the
        # uppercase tracking matches the other HUD micro-labels.
        "hyprland/submap" = {
          format = "{}";
          tooltip = false;
        };
        clock = {
          format = "{:%H:%M  ·  %a %b %d}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
        mpris = {
          format = "{status_icon} {dynamic}";
          dynamic-order = [
            "title"
            "artist"
          ];
          dynamic-len = 28;
          status-icons = {
            playing = "󰐊";
            paused = "󰏤";
            stopped = "󰓛";
          };
          tooltip-format = "{player}: {title} — {artist}";
          # click = play/pause, right-click = next are mpris module defaults
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
          tooltip-format-activated = "caffeine: screen stays on";
          tooltip-format-deactivated = "idle: lock at 5 min";
        };
        "custom/gpu" = {
          exec = "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits";
          format = "GPU {}°";
          interval = 10;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        memory = {
          format = "MEM {percentage}%";
          interval = 5;
          "min-length" = 8;
          on-click = "ghostty --class=TUI.float -e btop";
        };
        network = {
          format-wifi = "WIFI {signalStrength}%";
          format-ethernet = "ETH";
          format-disconnected = "OFFLINE";
          tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr}\n↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}";
          tooltip-format-wifi = "{essid} ({signalStrength}%): {ipaddr}";
          interval = 10;
          "min-length" = 9;
          on-click = "ghostty --class=TUI.float -e nmtui";
        };
        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "󰂱 {num_connections}";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "ghostty --class=TUI.float -e bluetui";
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTED";
          scroll-step = 3;
          on-click = "pavucontrol";
          on-click-right = "swayosd-client --output-volume mute-toggle";
        };
        "custom/notifications" = {
          format = "{icon}";
          format-icons = {
            notification = "󱅫";
            none = "󰂚";
            dnd-notification = "󰂛";
            dnd-none = "󰂛";
            inhibited-notification = "󱅫";
            inhibited-none = "󰂚";
          };
          return-type = "json";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
          tooltip = false;
        };
        tray = {
          spacing = 10;
          icon-size = 16;
        };
        "custom/power" = {
          format = "⏻";
          on-click = "hypr-power-menu";
          tooltip = false;
        };
      };

      xdg.configFile."waybar/style.css".text = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          border: none;
          border-radius: 0;
          min-height: 0;
        }
        window#waybar {
          background: transparent;
          color: ${pal.base05};
        }
        tooltip {
          background: rgba(${cssRgb pal.base01}, 0.95);
          border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
          border-radius: 10px;
        }
        tooltip label {
          color: ${pal.base05};
        }
        /* Floating frosted-glass module groups (Hyprland layer blur does the frosting).
           Site language: borders are NEUTRAL hairlines; accent only where focus lives.
           The inset top highlight is a PillNav-style "liquid sheen". */
        .modules-left,
        .modules-center,
        .modules-right {
          background: rgba(${cssRgb pal.base01}, 0.45);
          border: 1px solid rgba(${cssRgb pal.base05}, 0.07);
          box-shadow: inset 0 1px 0 rgba(${cssRgb pal.base05}, 0.06);
          border-radius: 14px;
          padding: 1px 10px;
          margin: 0 4px;
        }
        #workspaces button {
          color: ${pal.base04};
          padding: 0 9px;
          margin: 2px 2px;
          border-radius: 10px;
          font-size: 12px;
        }
        #workspaces button.active {
          color: ${pal.base07};
          background: rgba(${cssRgb pal.base0D}, 0.18);
        }
        #workspaces button.urgent {
          color: ${pal.base08};
        }
        #workspaces button:hover {
          background: rgba(${cssRgb pal.base05}, 0.06);
        }
        #submap {
          color: ${pal.base0D};
          padding: 0 10px;
          font-size: 11px;
          letter-spacing: 0.08em;
        }
        #clock {
          color: ${pal.base05};
          font-weight: bold;
          padding: 0 10px;
          font-size: 12px;
        }
        #mpris {
          color: ${pal.base06};
          padding: 0 9px;
          font-size: 12px;
        }
        #mpris.paused {
          color: ${pal.base04};
        }
        #idle_inhibitor {
          color: ${pal.base04};
          padding: 0 8px;
        }
        #idle_inhibitor.activated {
          color: ${pal.base0D};
        }
        /* HUD micro-labels: uppercase comes from the module format strings (GTK CSS
           has no text-transform); tracking lives here. mpris exempt — titles keep case. */
        #custom-gpu,
        #cpu,
        #memory,
        #network,
        #bluetooth,
        #pulseaudio {
          color: ${pal.base06};
          padding: 0 9px;
          font-size: 11px;
          letter-spacing: 0.08em;
        }
        #pulseaudio.muted,
        #bluetooth.disabled,
        #network.disconnected {
          color: ${pal.base03};
        }
        #custom-notifications {
          color: ${pal.base06};
          padding: 0 8px;
        }
        #custom-notifications.notification,
        #custom-notifications.inhibited-notification {
          color: ${pal.base0D};
        }
        #custom-notifications.dnd-notification,
        #custom-notifications.dnd-none {
          color: ${pal.base03};
        }
        #tray {
          padding: 0 6px;
        }
        #custom-power {
          color: ${pal.base04};
          padding: 0 10px 0 8px;
        }
        #custom-power:hover {
          color: ${pal.base08};
        }
      '';

      # fuzzel: session launcher (separate config path; launched via --config)
      xdg.configFile."fuzzel/hypr.ini".text = ''
        [main]
        font=JetBrainsMono Nerd Font:size=12
        prompt=>
        icon-theme=Papirus-Dark
        lines=10
        width=36
        horizontal-pad=20
        vertical-pad=16
        inner-pad=10
        layer=overlay

        [colors]
        background=${pal.raw.base00}cc
        text=${pal.raw.base05}ff
        prompt=${pal.raw.base04}ff
        placeholder=${pal.raw.base03}ff
        input=${pal.raw.base05}ff
        match=${pal.raw.base0D}ff
        selection=${pal.raw.base02}dd
        selection-text=${pal.raw.base07}ff
        selection-match=${pal.raw.base0C}ff
        border=${pal.raw.base0D}66

        [border]
        width=2
        radius=14
      '';

      # swayosd: glass OSD (server launched with --style above)
      xdg.configFile."swayosd/style.css".text = ''
        window {
          background: rgba(${cssRgb pal.base01}, 0.55);
          border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
          border-radius: 14px;
        }
        label {
          color: ${pal.base05};
          font-family: "JetBrainsMono Nerd Font", monospace;
        }
        progressbar trough {
          background: rgba(${cssRgb pal.base03}, 0.4);
        }
        progressbar progress {
          background: ${pal.base0D};
        }
        image {
          color: ${pal.base06};
        }
      '';

      # swaync: glassy notification center
      xdg.configFile."swaync/config.json".text = builtins.toJSON {
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        control-center-layer = "top";
        control-center-width = 380;
        control-center-margin-top = 10;
        control-center-margin-bottom = 10;
        control-center-margin-right = 10;
        control-center-margin-left = 10;
        notification-window-width = 380;
        timeout = 8;
        timeout-low = 5;
        timeout-critical = 0;
        fit-to-screen = true;
        widgets = [
          "title"
          "dnd"
          "notifications"
        ];
        widget-config = {
          title = {
            text = "notifications";
            clear-all-button = true;
            button-text = "clear";
          };
          dnd = {
            text = "do not disturb";
          };
        };
      };

      xdg.configFile."swaync/style.css".text = ''
        /* Explicit type scale — swaync otherwise inherits the (oversized) GTK default. */
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 12px;
        }
        .control-center {
          background: rgba(${cssRgb pal.base00}, 0.60);
          color: ${pal.base05};
          border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
          border-radius: 16px;
          margin: 8px;
          padding: 12px;
        }
        .notification-row .notification-background .notification {
          background: rgba(${cssRgb pal.base01}, 0.65);
          color: ${pal.base05};
          border: 1px solid rgba(${cssRgb pal.base05}, 0.08);
          border-radius: 14px;
          margin: 6px 4px;
          padding: 4px;
        }
        .notification-row .notification-background .notification.critical {
          border-color: ${pal.base08};
        }
        .notification .summary {
          font-size: 13px;
          font-weight: 600;
          color: ${pal.base05};
        }
        .notification .body {
          font-size: 12px;
          color: ${pal.base06};
        }
        .notification .app-name {
          font-size: 10px;
          color: ${pal.base04};
        }
        .notification .time {
          font-size: 10px;
          color: ${pal.base04};
        }
        .widget-title {
          color: ${pal.base05};
          font-size: 13px;
          font-weight: bold;
          padding: 4px 8px;
        }
        .widget-title > button {
          background: rgba(${cssRgb pal.base0D}, 0.14);
          color: ${pal.base05};
          font-size: 12px;
          border-radius: 10px;
          padding: 2px 10px;
        }
        .widget-dnd {
          color: ${pal.base04};
          font-size: 12px;
          padding: 4px 8px;
        }
        .notification-action {
          background: rgba(${cssRgb pal.base01}, 0.6);
          color: ${pal.base05};
          font-size: 12px;
          border-radius: 10px;
        }
      '';

      # hyprlock: frosted blur-over-wallpaper lock
      xdg.configFile."hypr/hyprlock.conf".text = ''
        background {
          monitor =
          path = ${config.home.homeDirectory}/wallpaper.png
          blur_passes = 4
          blur_size = 10
          noise = 0.035
          contrast = 0.9
          brightness = 0.7
          vibrancy = 0.25
        }

        input-field {
          monitor =
          size = 280, 50
          outline_thickness = 2
          dots_size = 0.25
          dots_spacing = 0.3
          outer_color = rgba(${pal.raw.base0D}ee)
          inner_color = rgba(${pal.raw.base01}cc)
          font_color = rgba(${pal.raw.base05}ff)
          check_color = rgba(${pal.raw.base0C}ee)
          fail_color = rgba(${pal.raw.base08}ee)
          placeholder_text = <span foreground="##${pal.raw.base04}">password</span>
          rounding = 14
          fade_on_empty = false
          position = 0, -40
          halign = center
          valign = center
        }

        label {
          monitor =
          text = $TIME
          font_size = 64
          font_family = JetBrainsMono Nerd Font
          color = rgba(${pal.raw.base05}ff)
          position = 0, 120
          halign = center
          valign = center
        }

        label {
          monitor =
          text = cmd[update:60000] date +"%A, %B %d"
          font_size = 18
          font_family = JetBrainsMono Nerd Font
          color = rgba(${pal.raw.base06}cc)
          position = 0, 60
          halign = center
          valign = center
        }
      '';

      # hypridle: lock then display off, but never auto-suspend — Hermes/Telegram
      # stays reachable while the screen is locked; manual suspend still works from
      # the power menu. hypridle/hyprlock keep their own hyprlang configs, but their
      # dpms calls go through hyprctl to Hyprland 0.55, which takes the Lua
      # dispatcher form: `hyprctl dispatch 'hl.dsp.dpms(...)'`.
      xdg.configFile."hypr/hypridle.conf".text = ''
        general {
          lock_cmd = pidof hyprlock || hyprlock
          before_sleep_cmd = loginctl lock-session
          after_sleep_cmd = ${hyprctl} dispatch 'hl.dsp.dpms({ action = "on" })'
        }

        listener {
          timeout = 300
          on-timeout = loginctl lock-session
        }

        listener {
          timeout = 360
          on-timeout = ${hyprctl} dispatch 'hl.dsp.dpms({ action = "off" })'
          on-resume = ${hyprctl} dispatch 'hl.dsp.dpms({ action = "on" })'
        }
      '';
    }

    # Opt the Hyprland session out of global Stylix so it carries the hyprland palette
    # (same idea as stylix.targets.niri.enable=false in home/shell.nix). Guarded:
    # stylix 25.11 may not declare a `hyprland` target, and if it doesn't, Stylix
    # never touches hypr/ anyway.
    (lib.optionalAttrs (options.stylix.targets ? hyprland) {
      stylix.targets.hyprland.enable = false;
    })
  ];
}
