# Comcreate Rice Upgrade Plan — kronos / Hyprland 0.55.3 (Lua era) — FINAL

## Vision

**One material, one light source, one color.** The desktop is a single sheet of warm espresso glass (`#141210` → `#211e1a` tonal steps), warm cream type (`#e8e4df`), and exactly one accent — comcreate azure `#7b7bff` — which appears only where focus lives: the active border, the focused workspace, the input caret, the match highlight. Depth comes from tonal elevation and restrained blur, not from color. Motion is the spice: fast, decelerating, physical — everything lands in under ~300ms perceived, opens eagerly, closes out of the way. Nothing rainbow, nothing wallpaper-driven; the comcreate palette in `lib/comcreate-palette.nix` is the single source of truth, interpolated by Nix into every artifact. NVIDIA-aware, dev-first: the terminal is the centerpiece and stays readable at all times.

**Two-session reality check (new, load-bearing):** kronos runs *two* login sessions sharing one home-manager config — niri+noctalia and Hyprland (Comcreate). Several components are shared (`~/wallpaper.png`, swww/awww, swayosd package, rice-dashboard script). **Every change below is scoped so it cannot leak into or break the niri session.** Rules of thumb baked into this plan:

- No session-agnostic HM systemd user services for daemons that niri already covers via noctalia (notifications, OSD, gamma). Hyprland-only services bind to `hyprland-session.target` or stay as `hl.on("hyprland.start")` autostarts.
- Shared files (`~/wallpaper.png`, the wallpaper-pick script, rice-dashboard) are edited once, compatibly for both sessions — never forked.
- The swww→awww rename touches **four** files atomically and only lands with the flake update that actually ships awww.

---

## What to Keep (already good)

- **The Lua dialect and file architecture.** `hyprland-comcreate.nix` → `xdg.configFile."hypr/hyprland.lua".text` with the `hl.*` API is current-era and correct. Keep the workspace `for` loop, the `hl.on("hyprland.start", ...)` autostart, the bind-option tables (`{ repeating = true }`, `{ locked = true }`, `{ mouse = true }`).
- **The floating frosted-pill waybar geometry** — transparent `window#waybar`, three pill groups, 14px radius, layer_rule blur. This is exactly the ML4W "glass center" look the ecosystem converged on. We tune it, we don't replace it.
- **The waybar relaunch bind as-is.** `pkill waybar || waybar` is fine: the niri session runs noctalia-shell, not waybar (plain-niri waybar retired 2026-06-08), so there is no cross-session collision to guard. Do not add a `$XDG_CURRENT_DESKTOP` test — the draft's guard was logically inverted anyway.
- **Keybind layout**: HJKL + arrows, TAB/SHIFT+TAB workspace cycling, fuzzel power menu, satty screenshot pipeline, swayosd repeating/locked binds. The muscle memory is right.
- **hypridle policy** (300s lock / 360s dpms / no suspend for Hermes reachability) and the flake-pinned `hyprctl` with the **Lua dispatcher string form** (`${hyprctl} dispatch 'hl.dsp.…'`) for dpms — keep, it's deliberate, and it's the canonical pattern every exec-dispatch in this plan reuses.
- **NVIDIA env strategy**: vars in `modules/nvidia.nix` `environment.sessionVariables` + the import-environment autostart, `cursor.no_hardware_cursors = 1` in-config. Correct division of labor. ⚠ VERIFY `NIXOS_OZONE_WL = "1"` is among them — without it Electron/Chromium apps land on blurry XWayland and the window-rule classes in 1.5 never match.
- **Portal routing** in `desktop-hyprland.nix` (hyprland/gtk split, niri non-collision) and the version-matched compositor + portalPackage pinning via the Hyprland flake + cachix.
- **The palette file itself.** `comcreate-palette.nix` with `raw.*` and semantic aliases is exactly the right design — the problem is nothing consumes it (see Jank #1).
- **Fonts**: JetBrainsMono Nerd Font everywhere already. Cohesion's hardest layer is done.
- **fuzzel as launcher** — keep it (minimalist's pick per research). It just needs its alpha lowered so the glass actually shows.
- **swaync via `xdg.configFile` + hyprland autostart** — this is *correct*, not legacy: the niri session's notification daemon is noctalia-shell, and the HM `services.swaync` module would ship a session-agnostic systemd service that races noctalia for the `org.freedesktop.Notifications` D-Bus name. Palette interpolation works fine in `xdg.configFile`; keep it there.
- **swayosd is already installed** (system-wide via `modules/desktop-niri.nix:72`, inherited by desktop-hyprland) and autostarted at hyprland.lua:268. Tier 2 only adds styling, not installation.
- **rice-dashboard exists and works** (`home/niri.nix` writeShellScriptBin: btop+cava+yazi tmux layout, shared by both sessions). The Tier 4 phosphor idea *modifies* this script; nothing is removed or re-implemented.
- **Bibata-Modern-Ice** cursor (monochrome-friendly); **Papirus-Dark** icons (Tier 4 has the one-liner azure folder fix).
- **`gaps_in = 6, gaps_out = 12`, `border_size = 2`** — inside ecosystem consensus (4–5/8–12 practical band). No change.
- **Smart gaps: explicitly rejected.** A gapless single-window workspace would kill rounding, border glow, and the floating-bar margin — the glass look needs its frame even with one window. Decision recorded so it stops being an open question.
- **Ghostty groundwork already done**: `background-opacity = 1.0`, `background-blur = false`, `stylix.targets.ghostty.enable = false` are all already in `home/ghostty.nix` (lines 37/38/6). Tier 3.2 lists only the *remaining* changes.

## Jank to Fix (audited & corrected — all addressed in tiers below)

1. **Palette bypass (the big one).** Every rgba/hex in hyprland.lua, fuzzel ini, hyprlock, waybar CSS, swaync CSS is hard-coded. Fix: every color literal becomes a Nix interpolation from `cc` — `rgba(${cc.raw.base0D}ee)`, `rgba(${cssRgb cc.base01}, 0.55)`. The `cssRgb` helper, concretely (goes in `lib/comcreate-palette.nix`):

   ```nix
   cssRgb = hex:
     let h = lib.removePrefix "#" hex;
     in lib.concatStringsSep "," (map (i: toString (lib.fromHexString (builtins.substring i 2 h))) [ 0 2 4 ]);
   ```

   One accent change = one file edit. This is Tier 0, done as part of every other change.
2. **`SUPER+Q`/`SUPER+W` duplicate close.** Free `W` → wallpaper picker; `Q` keeps close.
3. **Stale resize comment** — delete the "percent of dimension" line.
4. **wlsunset SLC coords ×3** (hyprland config *and* `niri-noctalia.nix:17/187`) — do **not** hoist into a `let` binding as interim work; go straight to the Tier 2.6 hyprsunset migration (hyprland session) and leave niri's wlsunset alone until/unless niri migrates too.
5. **`hypr-wallpaper-pick` extension lie + shared-contract trap.** `~/wallpaper.png` is a *cross-session contract*: niri autostart (`niri-noctalia.nix:18`), niri picker (`niri.nix:25`), hyprlock background, and hyprland autostart all read/write it. Fix that keeps the contract: the pick script runs `magick "$src" ~/wallpaper.png` (real PNG bytes, same path) instead of `cp`. No symlinks, no `.img.<ext>` — both sessions and hyprlock stay in sync automatically, which also fixes the lock-screen-shows-stale-wallpaper seam for free.
6. **`~/wallpaper.png` must pre-exist** — `home.activation` seed that *converts*: `magick ${./wallpaper/fam.jpg} ~/wallpaper.png` (a plain copy would recreate Jank #5's JPEG-bytes-named-png bug). First login never silently fails.
7. **CSS cosmetics** — stray blank line, no-op `box-shadow: none`.
8. **hypridle dpms Lua-string coupling** — keep, but add a comment block with the 0.54 fallback string so a version bump is a one-line revert.
9. **`border` speed-5/easeOutQuad oddity** — replaced wholesale by the Tier 1 animation tree.
10. **Memory staleness** ("Hyprland (Comcreate)" tile) — update `project_hyprland_comcreate_session.md` after implementation; the rig is still "not yet live-tested" — Tier 1 is the first live test.
11. **`~/Pictures/Screenshots` missing** — `home.file."Pictures/Screenshots/.keep".text = "";` so `Print` never fails.
12. **swww → awww rename — gated, not "when convenient."** The currently pinned nixpkgs (fef9403a, 2026-02-08) still ships *real* swww (`swww`, `swww-daemon` both in `/run/current-system/sw/bin`); renaming now breaks **both** sessions. When the flake update lands awww, sweep **all four** reference sites in one commit: `hyprland-comcreate.nix`, `niri-noctalia.nix:15,18`, `niri.nix:25`, `desktop-niri.nix:58`. ⚠ VERIFY the binary name at that time (`nix eval nixpkgs#awww.meta.mainProgram`).

---

## Tier 1 — Core Feel (animations + blur + decoration)

*Biggest visual payoff per line of config. All in `hyprland-comcreate.nix`'s Lua template, all colors via `${cc.raw.*}`.*

### 1.1 Animation tree rebuild

Philosophy (synthesized from upstream 0.55 defaults, end-4's MD3-expressive set, HyDE-optimized): **decel-heavy In, fast-linear Out, In > Out asymmetry, spring for windows, nothing over 4ds except workspaces.** Your current 2-curve set becomes 5 curves + 1 spring:

```lua
-- Curves (audit dialect: hl.curve + bezier= reference)
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}    } }) -- MD3: the workhorse
hl.curve("menuDecel",       { type = "bezier", points = { {0.1, 1},     {0, 1}      } }) -- instant-feel layers
hl.curve("menuAccel",       { type = "bezier", points = { {0.52, 0.03}, {0.72, 0.08} } }) -- layer exit
hl.curve("easeOutExpo",     { type = "bezier", points = { {0.16, 1},    {0.3, 1}    } }) -- canonical, border/fade
hl.curve("almostLinear",    { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}   } }) -- upstream fade default

-- ⚠ VERIFY: spring curves are documented for 0.55 (wiki + release notes #14171) as
-- hl.curve("name", { type = "spring", mass = 1, stiffness = N, dampening = N })
-- referenced via `spring = "name"` in hl.animation — but the audit only confirmed
-- the `bezier =` key in your dialect. Test on a throwaway leaf first; if the spring
-- key errors, fall back to emphasizedDecel for windows.
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 }) -- upstream default spring, near-critically damped

-- Animation leaves (speed in ds; 1ds = 100ms)
hl.animation({ leaf = "windows",     enabled = true, speed = 3.5, spring = "easy" })                                 -- ⚠ VERIFY spring key
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.8, bezier = "almostLinear",    style = "popin 90%" }) -- close gets out of the way
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 3,   bezier = "easeOutExpo" })
hl.animation({ leaf = "fade",        enabled = true, speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 1.7, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 1.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 2,   bezier = "almostLinear" })
-- Layers: THE missing piece — bar/fuzzel/swaync/swayosd currently animate with defaults
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.5, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "menuAccel",       style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.6, bezier = "menuDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8, bezier = "menuAccel" })
-- Workspaces: long-but-decelerating reads smooth, not slow
hl.animation({ leaf = "workspaces",   enabled = true, speed = 4.5, bezier = "menuDecel", style = "slide" })
-- Special workspace (new — see 1.4)
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.5, bezier = "menuAccel",       style = "slidefadevert 15%" })
```

One real `binds` tweak (merged into the **existing** `hl.config({ ... })` block, not a standalone paste):

```lua
binds = { scroll_event_delay = 0 },
```

*(The draft's `animate_manual_resizes = false` / `animate_mouse_windowdragging = false` are Hyprland defaults — no-ops, dropped.)*

**Do NOT add `borderangle` with `style = "loop"`** — it forces full-refresh-rate rendering permanently (~2× idle power measured, hyprdots#641; defeats NVIDIA idle clocks). The tasteful option is Tier 4's `once` sweep.

### 1.2 Blur — deepen the frost, cap the cost

**Intentional change: `size 8 → 6`** — paired with the new `brightness = 0.85` darkening, 6/3 reads identically deep while costing less; this is a declared tradeoff, not drift. `vibrancy` stays at the existing `0.18` (a 0.01 nudge is churn). Target block (`decoration.blur` in `hl.config`):

```lua
blur = {
  enabled = true,
  size = 6, passes = 3,            -- was 8/3; see note above. Drop to 5/2 if GPU runs hot
  new_optimizations = true,
  xray = true,                     -- NEW: biggest perf lever; terminal-over-browser blurs wallpaper, not content — better for dev focus anyway
  ignore_opacity = true,
  noise = 0.02,                    -- keep: film grain sells glass
  contrast = 0.9,
  brightness = 0.85,               -- NEW: slightly darkened backdrop = text contrast on cream type
  vibrancy = 0.18, vibrancy_darkness = 0.0,  -- keep current; ≤0.25 for monochrome; do NOT copy end-4's 0.5
  popups = true, popups_ignorealpha = 0.2,   -- NEW: blurred right-click menus
  special = false,                 -- expensive; revisit only if scratchpad lives over busy content
},
```

NVIDIA flags: blur is *the* dominant compositor GPU cost (~20% vs ~1% idle, hyprwm#7188) — `xray = true` + `passes ≤ 3` + `debug.vfr` left at default `true` is the budget. 0.55 defaults to FP16 buffers; if blur ever renders broken, escape hatch is `render.use_shader_blur_blend = true`. ⚠ VERIFY on a 10-bit monitor: blur banding (hyprwm#3822) → drop to 8-bit.

### 1.3 Decoration: tonal elevation + glass edge

```lua
decoration = {
  rounding = 14,
  rounding_power = 2.5,            -- NEW in your config: subtle squircle, smoother than pure circle
  active_opacity = 1.0,            -- CHANGE from 0.97: globals at 1.0, translucency via per-app rules only (see 1.5)
  inactive_opacity = 0.95,         -- raise from 0.90 — 0.90 over blur was muddying inactive editors
  fullscreen_opacity = 1.0,
  dim_inactive = true, dim_strength = 0.05,   -- lower from 0.08; whisper-level with the opacity cue
  shadow = {
    enabled = true,
    range = 20, render_power = 4,             -- big radius, fast falloff = "lifted pane"
    color = "rgba(00000033)",                 -- LOWER alpha than current 55 — heavy shadow kills glass
    color_inactive = "rgba(0000001a)",
    offset = {0, 4},                          -- light from above
  },
  -- NEW in 0.55: inner glow = light-through-glass edge, very on-theme
  glow = {
    enabled = true, range = 8, render_power = 3,
    color = "rgba(${cc.raw.base0D}22)",       -- whisper of azure on the active pane
    color_inactive = "rgba(00000000)",
  },  -- ⚠ VERIFY decoration.glow exists in 0.55.3 exactly as documented (it's a 0.55 feature; check `hyprctl version` build)
},
general = {
  border_size = 2,
  ["col.active_border"] = {
    colors = { "rgba(${cc.raw.base0D}ee)", "rgba(${cc.raw.base07}44)" },  -- azure → warm-white shimmer: "light catching the edge" (replaces azure→azure-bright; base0C moves to Tier 4 borderangle option)
    angle = 45,
  },
  ["col.inactive_border"] = "rgba(${cc.raw.base07}15)",  -- faint warm rim instead of dark base02 line — glass, not gutter
},
```

### 1.4 Special workspace (scratchpad) — currently absent entirely

**Primary = native Lua dispatcher; fallback = the config's own established pattern** (flake-pinned `${hyprctl}` + Lua dispatcher *string* — same as the hypridle dpms lines; the pre-0.55 `hyprctl dispatch togglespecialworkspace` form from the draft is wrong for this build and was the part most likely to silently fail):

```lua
-- Primary (⚠ VERIFY name against stubs at ${hyprland}/share/hypr/stubs):
hl.bind(mod .. " + grave",         hl.dsp.workspace.toggle_special({ name = "scratch" }))
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))
-- Fallback if the native form errors (known-good dialect, matches hypridle's usage):
-- hl.bind(mod .. " + grave", hl.dsp.exec_cmd([[${hyprctl} dispatch 'hl.dsp.workspace.toggle_special({ name = "scratch" })']]))
hl.window_rule({ match = { workspace = "special:scratch" }, opacity = "0.92 0.92" })
```

With the `specialWorkspaceIn/Out` leaves from 1.1, the scratchpad drops in with a `slidefadevert` — the single most "alive"-feeling daily interaction you're currently missing. Put a persistent ghostty+tmux session there. (Tier 4's hyprexpo goes on `SUPER+O` — grave belongs to the scratchpad, full stop.)

### 1.5 Window rules — from 5 rules to a real set (carrying ALL current rules forward)

The current 5 rules are **edited/extended, not replaced**. Explicitly carried forward: the `Picture-in-Picture` float rule and the global `suppress_event = "maximize"` (hyprland.lua:165,167) — dropping either is a regression.

```lua
-- CARRIED FORWARD (existing, unchanged):
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = {}, suppress_event = "maximize" })
-- Terminal is the glass centerpiece; rule owns opacity (ghostty background-opacity is already 1.0)
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, opacity = "0.94 0.88" })  -- the ONLY place terminal alpha lives
-- Content surfaces: opaque + unblurred (readability + perf; video shimmer gone)
hl.window_rule({ match = { class = "^(firefox|chromium|zen|Brave-browser)$" }, opacity = "1.0 override 1.0 override" })
hl.window_rule({ match = { class = "^(mpv|vlc|imv)$" }, opaque = true, no_blur = true })
-- Video shouldn't lock the screen mid-movie (your 300s hypridle WILL fire today)
hl.window_rule({ match = { class = "^(mpv|vlc)$" }, idle_inhibit = "always" })
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })  -- ⚠ VERIFY match-key name for fullscreen state in the Lua rule dialect
-- Floats get deterministic geometry — keep BOTH pavucontrol patterns until `hyprctl clients` confirms the new class name
hl.window_rule({ match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol)$" }, float = true, size = "900 600", center = true })
hl.window_rule({ match = { class = "^(TUI\\.float)$" }, float = true, size = "1100 700", center = true })
-- Dialogs/pickers
hl.window_rule({ match = { title = "^(Open File|Save File|File Upload)" }, float = true, center = true })
-- XWayland legacy junk: no rounding artifacts
hl.window_rule({ match = { xwayland = true, floating = true }, no_shadow = true })  -- ⚠ VERIFY xwayland match key
```

Plus `xwayland = { force_zero_scaling = true }` in `hl.config` (you have xwayland.enable but no section).

### 1.6 Input feel (dev-first — keyboard latency beats any blur value)

New `input` block (merge into `hl.config`); ⚠ VERIFY against existing input settings before overwriting `kb_options`:

```lua
input = {
  repeat_rate = 40, repeat_delay = 250,   -- snappy held-key repeat for vim motions
  accel_profile = "flat",                 -- desktop mouse: no accel
  follow_mouse = 1,
  kb_options = "caps:escape",             -- confirm not already set elsewhere
},
```

### 1.7 Monitor pinning

Replace the stub with a named line — on a desktop NVIDIA box you want explicit refresh:

```lua
hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1, vrr = 1 })
-- ⚠ VERIFY actual output name/modes via `hyprctl monitors`; vrr key name in Lua monitor table unconfirmed — fallback: classic `vrr = 1` key or omit
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })  -- keep catch-all as fallback
```

---

## Tier 2 — Shell (bar · launcher · notifications · lock/idle · OSD)

**Decision: Path A (evolutionary).** Keep the waybar glass rice and harden it; fuzzel stays. Noctalia-on-Hyprland (nixpkgs `noctalia-shell` 4.7.5, natively supports Hyprland) is the documented **optional branch** for session convergence with niri — defer until v5 stabilizes.

**Session-scoping rule for everything in this tier:** the four `hl.layer_rule` lines for `waybar` / `launcher` / `swaync-control-center` / `swaync-notification-window` **already exist** (hyprland.lua:157–160, with `ignore_alpha = 0`). All "layer rule" items below are **edits to those four lines** (raising `ignore_alpha`), never duplicate rules. Only `dim_around` (fuzzel) and `blur_popups` (waybar) are genuinely new.

### 2.1 Waybar — module gaps + glass tuning + pinned numbers

Migrate config/style to `programs.waybar.{settings,style}` for interpolation hygiene, **but keep `programs.waybar.systemd.enable = false`** — the HM systemd unit rides generic graphical-session targets and would paint waybar on top of noctalia in the niri session. The hyprland autostart line stays the launcher. (If you ever want the unit, set `systemd.targets = [ "hyprland-session.target" ]` — but autostart is simpler and already correct.)

- **Pinned geometry/typography** (so CSS tweaks converge instead of drifting): `height = 34`, `"margin" = "8 12 0 12"`, pill padding `4px 12px`, UI text 13px, mono (clock/workspace numbers) 12px.
- **Add modules**: right side gains `custom/notifications` (swaync bell: `exec = "swaync-client -swb"`, `return-type = "json"`, `on-click = "swaync-client -t -sw"`) — you have binds but no visible indicator; `custom/gpu` (`exec = "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits"`, interval 10, format `"gpu {}°"`) — it's an NVIDIA box with cpu/mem already shown. `backlight`: desktop, skip.
- **Optional left-side dev win**: `custom/tmux` (`exec = "tmux display-message -p '#S #I:#W' 2>/dev/null"`, interval 2) — lets Tier 3 strip the tmux statusline entirely, one info surface instead of two.
- **CSS**: keep pill groups; lower group bg alpha 0.55 → **0.45** so the deeper Tier 1 blur reads (`rgba(${cssRgb cc.base01}, 0.45)`); active workspace pill: bg `rgba(${cssRgb cc.base0D}, 0.18)`, 1px bottom border `${cc.base0D}` (the only solid accent on the bar); everything else cream/taupe. Fix the two cosmetic warts. **Tooltips** (otherwise stock-GTK white boxes over glass):

```css
tooltip {
  background: rgba(${cssRgb cc.base01}, 0.95);
  border: 1px solid rgba(${cssRgb cc.base0D}, 0.18);
  border-radius: 10px;
}
tooltip label { color: ${cc.base05}; }
```

- **Layer rule edit** (the existing waybar rule at hyprland.lua:157 — set ignore_alpha just *below* the CSS alpha so transparent gaps between pills don't haze):

```lua
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.35, blur_popups = true })
```

⚠ VERIFY `blur_popups` as a layer-rule effect key in your build (documented current wiki; the audit only shows `blur`/`ignore_alpha` in use).

### 2.2 Fuzzel — make the glass real

Current bg `141210ee` (93%) defeats the blur. In `fuzzel/comcreate.ini`:

```ini
[colors]
background=${cc.raw.base00}cc        ; 80% — blur now visible
text=${cc.raw.base05}ff
match=${cc.raw.base0D}ff
selection=${cc.raw.base02}dd
selection-match=${cc.raw.base0C}ff
selection-text=${cc.raw.base07}ff
border=${cc.raw.base0D}66            ; soften from full-strength azure ring
```

Compositor side: **edit** the existing `launcher` layer rule to `ignore_alpha = 0.5`, and add the one new effect:

```lua
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.5 })  -- EDIT of existing rule
hl.layer_rule({ match = { namespace = "launcher" }, dim_around = true })                -- NEW: spotlight dim
```

*(Optional branch: `programs.vicinae` — 0.20.12 in nixpkgs, daemon-fast, built-in clipboard. Only if fuzzel starts feeling thin.)*

### 2.3 swaync — same alpha discipline, same delivery mechanism

**Stay on `xdg.configFile` + hyprland autostart** (see "What to Keep" — the HM module's service would race noctalia for the notifications D-Bus name in the niri session). Palette interpolation works in `xdg.configFile` already.

style.css: control center `rgba(${cssRgb cc.base00}, 0.60)` (down from 0.7), notifications `rgba(${cssRgb cc.base01}, 0.65)` (down from 0.78), borders `rgba(${cssRgb cc.base0D}, 0.18)` unchanged, critical stays `${cc.base08}`. Compositor: **edit** the two existing swaync layer rules to `ignore_alpha = 0.5`.

### 2.4 swayosd — style it (it's already installed and autostarted)

Installation is a non-issue (system package via desktop-niri.nix:72; autostart at hyprland.lua:268). **Do not adopt `services.swayosd`** without first checking noctalia's own OSD in the niri session — the session-agnostic HM service would risk double OSDs there. Instead: keep the autostart, add `--style` pointing at a comcreate CSS shipped via `xdg.configFile."swayosd/style.css"`:

```css
window {
  background: rgba(${cssRgb cc.base01}, 0.55);
  border: 1px solid rgba(${cssRgb cc.base0D}, 0.18);
  border-radius: 14px;
}
progressbar trough { background: rgba(${cssRgb cc.base03}, 0.4); }
progressbar progress { background: ${cc.base0D}; }
label { color: ${cc.base05}; font-family: "JetBrainsMono Nerd Font"; }
```

```lua
hl.layer_rule({ match = { namespace = "swayosd" }, blur = true, ignore_alpha = 0.4 })  -- NEW namespace rule (none exists)
```

⚠ VERIFY swayosd's GTK CSS node names (`window`/`progressbar`) against the nixpkgs version — selectors have shifted between releases. ⚠ VERIFY the autostart line accepts `--style` in that version.

### 2.5 hyprlock + hypridle — palette-ify, HM-ify (true parity this time)

hyprlock stays hyprlang (it never went Lua). Migrate to `programs.hyprlock.settings` — **and delete the existing `xdg.configFile` hyprlock block in the same commit** (both write `hypr/hyprlock.conf`; HM aborts on the file collision). Parity details the draft got wrong, now preserved: `fade_on_empty = false` (current behavior) and the gray pango placeholder:

```nix
programs.hyprlock.settings = {
  background = { path = "${config.home.homeDirectory}/wallpaper.png";
                 blur_passes = 3; blur_size = 8; noise = 2.0e-2; contrast = 0.9; brightness = 0.7; vibrancy = 0.17; };
  input-field = { outer_color = "rgba(${cc.raw.base0D}ee)"; inner_color = "rgba(${cc.raw.base01}cc)";
                  font_color = "rgb(${cc.raw.base05})"; rounding = 14; outline_thickness = 2;
                  placeholder_text = "<span foreground=\"##${cc.raw.base04}\">comcreate</span>";  # keep pango form
                  fade_on_empty = false;                                                          # keep current behavior
                  check_color = "rgba(${cc.raw.base0C}ee)"; fail_color = "rgba(${cc.raw.base08}ee)"; };
  label = [ /* keep 64pt $TIME + 18pt date, fonts unchanged */ ];
};
```

Keep hypridle exactly as-is (audited as deliberate). Skip the brightness-dim listener — desktop DP monitors have no `brightnessctl` backlight.

### 2.6 Night light: wlsunset → hyprsunset (session-scoped!)

`services.hyprsunset` replaces wlsunset *in the hyprland session* and erases Jank #4's coordinate duplication. **Critical fix from review: scope the unit**, otherwise the session-agnostic service also runs under niri and fights niri's wlsunset (`niri-noctalia.nix:15–17`) — two wlr-gamma-control clients clash:

```nix
services.hyprsunset = {
  enable = true;
  systemdTarget = "hyprland-session.target";   # REQUIRED: never runs under niri
  settings = {
    profile = [
      { time = "06:30"; identity = true; }
      { time = "20:30"; temperature = 3500; }
    ];
  };
};
```

Remove the hyprland wlsunset autostart + bind; **leave niri's wlsunset untouched** (migrating niri to hyprsunset is a separate, optional follow-up). Rebind `SUPER+CTRL+N` to `hyprctl hyprsunset temperature 3500` / `identity` toggle. ⚠ VERIFY the settings schema for your hyprsunset version (profile-based scheduling is the current shape; older versions only took CLI flags).

### 2.7 Wallpaper motion — awww/swww transition values

"Motion is the spice" includes wallpaper switching. In the (shared!) pick script — works with current swww and future awww, both sessions:

```sh
swww img ~/wallpaper.png \
  --transition-type grow --transition-pos "$(hyprctl cursorpos 2>/dev/null || echo 0,0)" \
  --transition-fps 165 --transition-duration 0.7 --transition-bezier .05,.7,.1,1
```

(The `|| echo 0,0` keeps the shared script working when invoked from niri, where `hyprctl` fails.)

---

## Tier 3 — Cohesion (terminal · tmux · nvim · system palette · prompt)

**The strategic move: comcreate becomes the Stylix scheme.** Today app interiors are Catppuccin Macchiato inside an espresso/azure shell — the single biggest aesthetic fracture. Stylix accepts an inline base16 attrset, and the palette lib already *is* base16-shaped.

### 3.1 Stylix flip — `modules/stylix.nix`

```nix
# Source FROM lib/comcreate-palette.nix (strip '#'), never duplicated:
stylix.base16Scheme = { scheme = "comcreate"; author = "comcreate"; }
  // lib.mapAttrs (_: v: lib.removePrefix "#" v) cc.raw;
# Reference values: base00=141210 base01=1b1917 base02=211e1a base03=6b655d
# base04=8a847c base05=e8e4df base06=c5bfb5 base07=f2efe9 base08=e06c5e
# base09=d99a5c base0A=cbb46a base0B=3ddc84 base0C=72b8ff base0D=7b7bff
# base0E=a98bff base0F=2d8a4e
```

Effects: GTK, Qt, bat, fzf, lazygit, dconf — everything not opted out — snaps to comcreate for free. Keep existing opt-outs (`waybar`, guarded `hyprland`, `ghostty` already off) and **add**: `stylix.targets.tmux.enable = false`, `stylix.targets.neovim.enable = false` (if it fires). Wallpaper: `stylix.image` can stay `fam.jpg` (scheme no longer derived from it). Note stylix's hyprland target now supports Lua configType (PR #2316) — keep your opt-out; hand-tuned borders beat its generic base0D border.

**Beyond-GTK3 coverage (new — the classic theming gaps):**

- **Qt**: confirm `stylix.targets.qt.enable = true` (kvantum platform) so pavucontrol-qt/KDE utilities follow; ⚠ VERIFY it doesn't fight any existing `qt.style` setting.
- **libadwaita/GTK4**: base16 GTK theming fully lands only on GTK3. Confirm stylix uses `adw-gtk3` as the GTK theme (its default — verify), and add a GTK4 accent override:

  ```nix
  xdg.configFile."gtk-4.0/gtk.css".text = ''
    @define-color accent_bg_color ${cc.base0D};
    @define-color accent_color ${cc.base0D};
  '';
  ```

  ⚠ VERIFY this doesn't collide with a stylix-managed gtk-4.0/gtk.css (use `lib.mkForce` or stylix's extraCss hook if it does).
- **Portal dark-mode signal**: confirm `stylix.polarity = "dark"` sets dconf `color-scheme = prefer-dark` and that `xdg-desktop-portal-gtk` serves the settings portal in the hyprland/gtk split. Test: `busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings ReadOne ss org.freedesktop.appearance color-scheme`.

**Side effect to embrace**: swaylock (niri session) is hand-mapped to macchiato — remap its hex values to comcreate in the same pass (`inside #141210cc`, ring `#211e1a`, verify `#7b7bff`, wrong `#e06c5e`, key-hl `#7b7bff`).

### 3.2 Ghostty — comcreate palette (the remaining work only)

Already done in `home/ghostty.nix` and needing **no change**: `background-opacity = 1.0`, `background-blur = false`, stylix target off. The actual diff:

```ini
background = ${cc.base00}        # #141210
foreground = ${cc.base05}        # #e8e4df
cursor-color = ${cc.base0D}
selection-background = ${cc.base02}
selection-foreground = ${cc.base07}
# 16-slot map: 0=#1b1917 8=#6b655d 1/9=#e06c5e 2/10=#3ddc84 3/11=#cbb46a
#              4/12=#7b7bff 5/13=#a98bff 6/14=#72b8ff 7=#c5bfb5 15=#f2efe9
window-padding-x = 14            # up from 8 — research consensus 16px min for breathing room; 14 splits the difference with tmux borders
window-padding-y = 14
unfocused-split-opacity = 0.85   # NEW: dims inactive ghostty splits — free cohesion with dim_inactive
minimum-contrast = 1.1           # readability floor over transparency
```

Note: ghostty `background-blur` is **confirmed a no-op on Hyprland** (KDE-only on Linux, ghostty#4626) — already correctly false; blur comes from the compositor. Watch hyprwm#9705 (transparent ghostty going fully transparent on tab close) — if hit, pin opacity via the window rule `override` form.

### 3.3 tmux — design the seam (least-riced component today)

`home/tmux.nix` gets an explicit statusline + `stylix.targets.tmux.enable = false`:

```tmux
set -g status-position top
set -g status-style "bg=default"                       # transparent — ghostty alpha + compositor blur show through
set -g status-left "#[fg=${cc.base0D},bold] #S #[default]  "
set -g status-left-length 30
set -g status-right "#{?client_prefix,#[fg=${cc.base0D}] ⌘ ,}"   # accent prefix indicator, nothing else (clock lives in waybar)
set -g window-status-format "#[fg=${cc.base03}] #I:#W "
set -g window-status-current-format "#[fg=${cc.base05},bold] #I:#W "
set -g window-status-separator ""
set -g pane-border-style "fg=${cc.base02}"             # border ≈ bg: borderless look
set -g pane-active-border-style "fg=${cc.base0D}"      # the one accent line in the terminal
set -g pane-border-lines single
set -g message-style "bg=${cc.base01},fg=${cc.base05}"
set -g mode-style "bg=${cc.base02},fg=${cc.base07}"
```

Plugins — corrected for nixpkgs reality (`programs.tmux.plugins` takes nixpkgs derivations; there is no tpm path in the HM module, and **floax/sessionx are not in nixpkgs**):

- **vim-tmux-navigator** (packaged — add now; the single most important cohesion plugin: seamless C-hjkl across nvim/tmux).
- **tmux-floax**: optional — package it yourself via `pkgs.tmuxPlugins.mkTmuxPlugin { pluginName = "floax"; src = pkgs.fetchFromGitHub { ... }; }`. Worth it (floating scratch pane = special-workspace energy inside tmux), but it's a packaging chore, not a config line.
- **sessionx**: dropped (same packaging cost, less payoff).

If the waybar `custom/tmux` module from 2.1 ships, go further: `set -g status off` + prefix-toggle `bind b set status`.

### 3.4 Neovim — square.lua becomes comcreate.lua

The orphaned `colors/square.lua` is 90% of the work already done; it just speaks the wrong dialect (`#0055ff` on pure black). Port, don't rewrite:

1. **Copy `colors/square.lua` → `colors/comcreate.lua`** and remap the palette table: bg stays `NONE` (transparent — now it actually buys something: ghostty alpha + compositor blur underneath), fg `#e8e4df`, white `#f2efe9`, greys → warm ramp `#c5bfb5 / #8a847c / #6b655d / #211e1a / #1b1917`, comment `#6b655d` (square's `#3a3a3a` is too dark on espresso), panels `#141210 / #1b1917`, **accent `#7b7bff`** (+dark `#4a4ab8`, tint `#1a1a2e`), semantic red `#e06c5e`, yellow `#cbb46a`, green `#3ddc84`. All Telescope/Neo-tree/Noice/Snacks/Blink/Flash/grey-rainbow-remap coverage carries over verbatim.
2. **`ui.lua`: `current = "comcreate"`.** Mocha and the flavor split die.
3. **lualine**: custom theme table from the same palette (square has none — this is why lualine falls back to `auto`):
   ```lua
   local cc = { bg = "NONE", surface = "#1b1917", text = "#e8e4df", dim = "#8a847c", accent = "#7b7bff" }
   local comcreate_lualine = {
     normal  = { a = { fg = "#141210", bg = cc.accent, gui = "bold" }, b = { fg = cc.text, bg = cc.surface }, c = { fg = cc.dim, bg = cc.bg } },
     insert  = { a = { fg = "#141210", bg = "#3ddc84", gui = "bold" } },
     visual  = { a = { fg = "#141210", bg = "#a98bff", gui = "bold" } },
     replace = { a = { fg = "#141210", bg = "#e06c5e", gui = "bold" } },
     inactive = { a = { fg = cc.dim, bg = cc.bg }, b = { fg = cc.dim, bg = cc.bg }, c = { fg = cc.dim, bg = cc.bg } },
   }
   -- separator-less minimal: section_separators = "", component_separators = ""
   ```
   (Drop the powerline `` separators — separator-less is the 2025 minimal idiom and avoids bg-pair math over transparency.)
4. **bufferline**: either drop it for incline-only (more minimal), or give it explicit highlight overrides (`fill.bg = "NONE"`, `buffer_selected.fg = "#e8e4df"` bold, indicator `#7b7bff`) — the catppuccin integration won't fire anymore.
5. **Rainbow neutralization**: comcreate.lua inherits square's grey RainbowDelimiter remaps — keep the plugins installed, they render as structure-greys. Set ibl scope highlight to a single group: `scope.highlight = "IblScopeChar"` linked to fg `#7b7bff` — *one* accent scope line instead of a 7-color cycle.
6. **colorful-winsep** fallback `#b4befe` → `#7b7bff`; incline colors via `Normal`-linked groups; float windows: `NormalFloat`/`FloatBorder` bg `NONE`, `winblend = 0` (required over blur or floats look doubled).
7. **Smooth motion (the spice, in-editor)**: you already run snacks — enable `snacks.scroll` (scrolloff-correct smooth scrolling). Cursor smear: choose ONE layer — either `sphamba/smear-cursor.nvim` *or* the Tier 4 ghostty shader, never both.

### 3.5 Shell prompt + CLI cohesion (new — the inside of the centerpiece)

The terminal is the centerpiece, but the prompt still wears default colors. Add:

- **starship** with a comcreate palette block: directory/branch in `#e8e4df`, the prompt character and active segment in `#7b7bff`, dim metadata `#6b655d`, error state `#e06c5e`. Single-line, no powerline blocks (matches the separator-less lualine idiom).
- **fish**: `set -U fish_color_command e8e4df`, `fish_color_param c5bfb5`, `fish_color_autosuggestion 6b655d`, `fish_color_error e06c5e`, selection/search-match on `#211e1a`/`#7b7bff`.
- **LS_COLORS**: `vivid` with a comcreate theme (or accept eza defaults — they're tame). ⚠ VERIFY whether stylix already themes fish before hand-setting (avoid fighting it).

### 3.6 Fonts — no change, one addition

JetBrainsMono Nerd Font stays the system mono (already universal). Optional refinement: waybar/swaync UI text → **Inter** at 13px (grotesque sans for UI, mono only for clock/workspace numbers — the namishh-guide pattern); a 2-line waybar CSS `font-family` change, not a system change. Skip Berkeley Mono unless you feel like paying.

---

## Tier 4 — Delight (extras)

### 4.1 Overview plugin — hyprexpo

The flagship interaction of the modern rices. **Critical NixOS rule: plugin and compositor must be built from the same source.** You run the upstream Hyprland flake → use the plugin from `hyprland-plugins` flake with `inputs.hyprland.follows = "hyprland"`; **never** `pkgs.hyprlandPlugins.*` (built against nixpkgs' Hyprland → "Version mismatch" at load).

```nix
# flake.nix
inputs.hyprland-plugins = {
  url = "github:hyprwm/hyprland-plugins";
  inputs.hyprland.follows = "hyprland";
};
# Current setup (hand-written hyprland.lua, no HM hyprland module): load via config —
# plugin = ${hyprexpo}/lib/libhyprexpo.so  ⚠ VERIFY Lua-era plugin-load syntax
```

Config + bind (**SUPER+O** — grave is the scratchpad, per 1.4):

```lua
hl.config({ plugin = { hyprexpo = {
  columns = 3, gap_size = 8,
  bg_col = "rgb(${cc.raw.base00})",
  workspace_method = "first 1",
}}})
hl.bind(mod .. " + O", ...)
```

⚠ VERIFY twice: (a) hyprexpo builds against 0.55.3 — 0.55's config overhaul is exactly where plugin ABI lags; check the plugins repo pin; (b) `plugin.*` config-key passthrough shape in the Lua dialect. If either fails, defer — everything else stands alone.

### 4.2 Screenshot flow upgrade — grimblast

Replace the hand-rolled grim+slurp pipelines with `grimblast` (official hyprwm/contrib, in nixpkgs) — adds `--freeze`:

```lua
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd([[grimblast --freeze save area - | satty -f - --output-filename ~/Pictures/Screenshots/satty-$(date +%Y%m%d-%H%M%S).png]]))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("grimblast --freeze copy output"))
hl.bind("Print",               hl.dsp.exec_cmd("grimblast save output ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"))
```

`home.packages`: add `grimblast` (keep grim/slurp — grimblast wraps them).

### 4.3 Color picker (new — rice-adjacent dev staple)

```lua
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))   -- copies hex to clipboard
```

`home.packages`: add `hyprpicker`.

### 4.4 Ghostty cursor shader — terminal-level smear

Ghostty 1.2 cursor uniforms enable GLSL cursor trails:

```nix
xdg.configFile."ghostty/shaders/cursor_smear.glsl".source = ./shaders/cursor_smear.glsl;  # from sahaj-b/ghostty-cursor-shaders, parametrize color to 7b7bff
# ghostty config:
custom-shader = ~/.config/ghostty/shaders/cursor_smear.glsl
custom-shader-animation = always
```

⚠ VERIFY: effects are keyed to **block** cursors; your ghostty uses a **bar** cursor — beam handling is unresolved upstream (ghostty discussion #7865). Test; if the smear glitches on bar, either switch `cursor-style = block` or use smear-cursor.nvim instead. Pick one layer only (see 3.4.7).

### 4.5 Animated border option — the `once` sweep

The tasteful version of the gradient-border animation (zero steady-state GPU cost, unlike `loop`):

```lua
hl.animation({ leaf = "borderangle", enabled = true, speed = 82, bezier = "almostLinear", style = "once" })
```

One slow 45°→405° sweep of the azure→warm-white gradient on config reload / certain events, then static. This is where `base0C` can re-enter: optional 3-stop gradient `{ "rgba(${cc.raw.base0D}ee)", "rgba(${cc.raw.base0C}ee)", "rgba(${cc.raw.base07}44)" }`. **Never `style = "loop"`** (≈2× idle power, renders every frame forever).

### 4.6 Misc delight

- **Cursor, fully wired** (replaces the half-measure): `home.pointerCursor = { package = pkgs.bibata-cursors; name = "Bibata-Modern-Ice"; size = 24; gtk.enable = true; x11.enable = true; }` for GTK/XWayland consistency, **plus** `hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")` next to the existing size vars (⚠ VERIFY recent `pkgs.bibata-cursors` ships hyprcursor variants, and that pointerCursor's size doesn't collide with the existing cursor-size env vars).
- **Papirus folders → azure-adjacent**: `papirus-folders -C indigo --theme Papirus-Dark` via a `home.activation` script (closest stock color to `#7b7bff`); one-liner, kills the blue-folder mismatch.
- **Login greeter on-palette** (first pixel of the session): tuigreet flags → `greetd.tuigreet --time --remember-session --theme 'border=#7b7bff;text=#e8e4df;prompt=#8a847c'`. Small, system-level, cheap.
- **Group/tabbed windows**: `hl.bind(mod .. " + G", hl.dsp.layout("togglegroup"))` ⚠ VERIFY dispatcher form — groupbar themed by `general.col.*group*` keys (locked-active `base0C`, rest surface tones).
- **The phosphor easter egg**: `phosphorBg`/`phosphorText` (`#0a1a0a`/`#33ff33`) are defined and unused — wire them into the **existing** rice-dashboard script's btop pane (`TUI.float` window rule + a btop comcreate-phosphor theme) so `SUPER+CTRL+T` drops a retro green-phosphor monitor pane. Modify the shared script compatibly — it runs under niri too. Brand motif, zero cost, pure delight.

---

## Verification Ritual (new)

Every tier gets a before/after capture and a known escape hatch:

- **Capture**: `mkdir -p ~/rice-log; grimblast save output ~/rice-log/$(git -C ~/dotfiles rev-parse --short HEAD).png` before and after each implementation step (use grim until 4.2 lands).
- **Rollback**: `nh os rollback` (or boot the previous generation) — every step below is one `nrs` away from undo.
- **Generated-artifact diff** for refactor-only steps (Tier 0): `diff <(old) <(new)` on the files in `~/.config/hypr`, `~/.config/waybar`, etc. — zero visual change expected means zero diff expected (modulo color-source comments).

## Implementation Order

Ordered for payoff-per-risk; each step is independently shippable + `nrs`-testable. Tier 1 first because the box is "not yet live-tested" anyway — test the core before decorating.

- [ ] **0. Plumbing pass** — add `cssRgb` helper (Jank #1, implementation given) to `comcreate-palette.nix`; sweep ALL hard-coded colors in `hyprland-comcreate.nix` (Lua, fuzzel ini, hyprlock, waybar CSS, swaync CSS) to `${cc.raw.*}` / `${cssRgb cc.*}` interpolations. Zero visual change — verify by diffing generated artifacts.
- [ ] **1. Quick jank batch** — drop `SUPER+W` close-bind (→ wallpaper picker); delete stale resize comment; `home.file."Pictures/Screenshots/.keep"`; wallpaper `magick`-convert in pick script + activation seed (Jank #5/#6 — keeps the shared `~/wallpaper.png` contract for both sessions); CSS cosmetics. *(No wlsunset hoist — superseded by step 6. No waybar-toggle guard — non-issue.)*
- [ ] **2. Tier 1 animations + input** — new curve set + full leaf tree + `scroll_event_delay` + input block. Test spring (`easy`) on `windows` first; fall back to `emphasizedDecel` if the `spring =` key errors. This is the moment the rig stops feeling default. **Capture before/after.**
- [ ] **3. Tier 1 decoration + blur** — blur block (xray!, size 6 declared), opacity strategy flip (globals 1.0 + rules), shadow/glow, border gradient, `rounding_power`. ⚠ glow key existence check.
- [ ] **4. Tier 1 rules + special workspace + monitor pin** — window-rule set (PiP + suppress_event carried forward, dual pavucontrol pattern), idle_inhibit, scratchpad bind (native Lua dispatcher, `${hyprctl}`-string fallback), named monitor line.
- [ ] **5. Tier 2 shell hardening** — swayosd CSS via `--style` (no HM service); fuzzel/swaync alpha drops + **edits to the four existing layer rules** + new `dim_around`/`blur_popups`/swayosd rules; waybar HM-module migration with **systemd off** + swaync-bell + GPU module + pinned geometry + tooltip CSS; hyprlock → `programs.hyprlock.settings` **removing the old xdg.configFile block**, parity preserved (fade_on_empty=false, pango placeholder).
- [ ] **6. hyprsunset migration** — `services.hyprsunset` with `systemdTarget = "hyprland-session.target"`; remove hyprland wlsunset autostart + bind; niri's wlsunset untouched.
- [ ] **7. Tier 3 Stylix flip** — comcreate base16 from the palette lib, new opt-outs (tmux/neovim), Qt/GTK4/portal-dark verifications, swaylock remap. Big blast radius: eyeball GTK apps, file pickers, bat, lazygit after rebuild.
- [ ] **8. Ghostty comcreate palette** + padding 14 + `unfocused-split-opacity` + `minimum-contrast` (opacity/blur/stylix-off already in place).
- [ ] **9. tmux statusline** + vim-tmux-navigator (nixpkgs); floax only via `mkTmuxPlugin` if appetite; decide waybar-tmux-module vs in-tmux status.
- [ ] **10. nvim**: `colors/comcreate.lua` port, `ui.lua` flip, lualine theme, ibl single-accent scope, winsep/float fixes, snacks.scroll.
- [ ] **11. Prompt/CLI cohesion** — starship comcreate palette, fish colors, optional vivid LS_COLORS.
- [ ] **12. swww → awww rename** — **only with the flake update that ships awww**; all four files (`hyprland-comcreate.nix`, `niri-noctalia.nix`, `niri.nix`, `desktop-niri.nix`) in one commit; add 2.7 transition flags in the same pass.
- [ ] **13. Tier 4, in order of confidence**: grimblast flow → hyprpicker bind → borderangle `once` → pointerCursor + hyprcursor → papirus-folders → tuigreet theme → phosphor btop (modify existing rice-dashboard) → ghostty cursor shader (⚠ bar-cursor) → hyprexpo on SUPER+O (⚠ ABI; flake-follows wiring) → groups.
- [ ] **14. Update memory** — `project_hyprland_comcreate_session.md`: login-tile reality, live-tested status, new component list, two-session sharing rules.

## Not Doing / Out of Scope

Explicitly excluded so the plan stays a minimalism/glass/motion/dev-cohesion plan, not a theming-everything plan:

- **Browser chrome theming** (Firefox/zen userChrome.css, dark-private toggles) — browsers are content surfaces in this design (opaque, unblurred, rule 1.5); their own dark modes suffice.
- **Discord/Spotify client CSS** (Vesktop/system24, spicetify) — not part of the dev loop on this box; revisit only if they become daily drivers.
- **Plymouth / TTY console colors** — boot path is seen for seconds; not worth the surface area. (tuigreet covers the first *interactive* pixel.)
- **Screen-recording bind + waybar dot** — no current recording workflow; add when one exists.
- **`xdg.mimeApps` default-app pinning** — orthogonal housekeeping; do it someday, not as part of the rice.
- **Per-tool theme files for yazi/delta/btop-main** — stylix covers bat/fzf/lazygit; ⚠ VERIFY whether its yazi/delta targets fire after the Tier 3 flip and only hand-theme what it misses.
- **Wallpaper curation / generated gradient wallpaper** — `fam.jpg` stays; the manifesto already decouples the palette from the wallpaper, and `xray = true` + hyprlock blur make the wallpaper a texture, not a color source.
- **Deferred branches** (unchanged from draft): Noctalia-on-Hyprland convergence (wait for v5); vicinae launcher swap; matugen accent-only experiments; HM `wayland.windowManager.hyprland` + `configType = "lua"` + `extraLuaFiles` migration (do after the rice settles).
