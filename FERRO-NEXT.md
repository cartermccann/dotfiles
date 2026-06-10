# Ferro Next — Workflow + Curation Pass

Companion to `RICE-PLAN.md` (which stays the authority for Hyprland animation/blur/
decoration, Stylix flip, nvim ferro.lua, waybar hardening). This plan adds three new
workstreams on top: **A** aesthetic refinements the rice research surfaced beyond
RICE-PLAN, **B** Omarchy-derived workflow tooling, **C** NixOS-flavored branding.
Nothing here duplicates a RICE-PLAN item; where research disagreed with RICE-PLAN,
the decision is recorded inline.

Sources: Omarchy master @ 9cf1852 (2026-06-08, post-v3.8.2 — there is **no 4.0**;
the in-flight master change is their Hyprland-config-to-Lua conversion, which we
already live in), plus rice-aesthetic research (end-4, caelestia, noctalia, shin,
DankMaterialShell, qylock, namishh's ricing guide). Full agent reports in session
history 2026-06-09.

## Ground rules

1. **NixOS-native or not at all.** Everything ships from this flake via home-manager.
   No `~/.local/share/omarchy` runtime, no mise (direnv/dev-shells are our answer),
   no update channels (generations). Scripts become `writeShellScriptBin` packages.
2. **Both sessions, one product.** Every user-facing piece (menu, screensaver,
   reminders, OCR) must work under niri+noctalia *and* Hyprland, honoring the
   RICE-PLAN two-session scoping rules (no session-agnostic daemons, shared files
   edited compatibly).
3. **Branding is NixOS/ferro, never Arch/Omarchy.** ASCII art = snowflake/ferro
   wordmark; "omarchy" appears nowhere user-visible.
4. **One accent, two hairline alphas, ≤7 visible bar modules.** The research's
   curation rules are binding for every new surface this plan adds.
5. **fish, not bash.** All ported functions are rewritten as fish functions in
   `home/shell.nix` (or a new `home/dev-workflow.nix`), not bash-sourced.

## Already true (verified 2026-06-09 — do not redo)

- niri springs are already critically damped (`niri-noctalia.nix:54-74`,
  `damping-ratio=1.0 stiffness=800/1000`) — the exact values the research
  recommends. Motion parity = Hyprland side only (RICE-PLAN Tier 1.1).
- Ghostty cursor shaders done: `cursor_warp.glsl` active (Neovide-style,
  EaseOutExpo, fade tail), `cursor_tail.glsl` + `cursor_smear.glsl` vendored as
  one-line swaps, `custom-shader-animation = always`. RICE-PLAN 4.4 is complete.
- Waybar uppercase labels via format strings; japandi glass + hairline borders;
  fuzzel dmenu pattern already used 3× (power menu, wallpaper, cliphist).
- git already has `pull.rebase` + `push.autoSetupRemote` (`home/git.nix`).

---

## Workstream A — Aesthetic refinement (delta over RICE-PLAN)

### A1. UI sans for chrome — commit, don't "optional" it
RICE-PLAN 3.6 lists Inter as optional; research says it's the single biggest
"agency" tell (caelestia→Rubik/GoogleSans, DMS→Inter Variable, namishh→Lexend).
**Decision: Inter for all chrome** — waybar, fuzzel, swaync, hyprlock labels,
tooltips, swayosd — at 10–11.5px weight 500; JetBrainsMono NF demoted to
terminal + numeric/glyph modules only.
- `fonts.packages`/`home.packages`: `inter` (nixpkgs).
- waybar CSS: `font-family: "Inter", "JetBrainsMono Nerd Font"`, keep uppercase
  in format strings, add `letter-spacing: 1.2px` on label modules (works in GTK
  CSS even though text-transform doesn't), `font-feature-settings: "tnum"` on
  the clock so it doesn't jitter.
- fuzzel: `font=Inter:size=12`.
- hyprlock: clock `Inter Display Light` (or Inter Light) huge + thin; date line
  small tracked uppercase (see A4).

### A2. Hairline grammar — standardize on exactly two alphas
Research: white-alpha hairlines (`rgba(255,255,255,0.06)` rest / `0.12` focus)
read correctly over any blur content. RICE-PLAN uses cream-alpha
(`${cc.base07}` @ 0.07–0.08) — same idea, warmer.
**Decision: keep cream (japandi warmth) but standardize on exactly two values**
defined once in `lib/ferro-palette.nix`:
```nix
hairline      = "rgba(${cssRgb cc.base07}, 0.07)";  # resting borders, dividers
hairlineFocus = "rgba(${cssRgb cc.base07}, 0.14)";  # hover/focus/active surface edges
```
Sweep every border in waybar/swaync/swayosd/fuzzel/tooltips/hyprlock input to one
of these two tokens. Azure stays reserved for focus/meaning (active window border,
active workspace, caret, OSD fill) per RICE-PLAN.

### A3. Selection = elevation, not accent fill
Fuzzel/menus: selected row becomes a +8% light overlay (`${cc.base02}` high-alpha
or cream@0.08), match characters brighten toward `${cc.base07}` instead of
recoloring azure. Amends RICE-PLAN 2.2's `[colors]` block:
```ini
selection=${cc.raw.base02}cc          ; elevation, not accent bar
match=${cc.raw.base07}ff              ; matches brighten…
selection-match=${cc.raw.base0D}ff    ; …azure only inside the selected row
```
Same rule applies to the ferro-menu (B1) since it's fuzzel underneath.

### A4. Hyprlock editorial layout
Refines RICE-PLAN 2.5 (palette/HM migration unchanged; layout upgraded):
110pt thin Inter clock, small-caps tracked date line (`date | tr a-z A-Z`,
letter_spacing 3), 260×46 input pill with hairline outline (A2 tokens),
`placeholder_text` empty, wallpaper blur+`brightness 0.72`. The lock screen is
the most-neglected agency surface (qylock reference). niri session: swaylock
gets the closest approximation in the same pass (it's already being remapped to
ferro in RICE-PLAN 3.1).

### A5. Radius & spacing scale — write it down
One scale, documented in `ferro-palette.nix` comments and used by every new
surface: **radius 10 (tooltips/small) · 14 (pills, windows, notifications) ·
23 (lock input = half its height); gap unit 12 (gaps_out = bar margin =
notification margin); terminal padding 14.** Existing values already comply;
this just stops drift.

### A6. Motion — remaining gaps after RICE-PLAN Tier 1.1
- RICE-PLAN's curve set is confirmed by the research (same M3 family as end-4);
  no changes. Implement as written.
- **New**: niri `window-open` / `window-close` — verify `niri-noctalia.nix` has
  explicit open/close (research rec: open 300ms ease-out-expo, close 200ms
  ease-out-quad) so window lifecycle matches Hyprland's popin-in/fast-out feel.
- **New**: noctalia-shell animation/duration settings — check what its config
  exposes and align durations (sub-350ms) with the Hyprland layer animations.
- Wallpaper transition flags (RICE-PLAN 2.7) remain gated on awww.

---

## Workstream B — Omarchy workflow ports

### B1. ferro-menu — fuzzel-dmenu system menu (highest impact)
Omarchy's `omarchy-menu` pattern (~1000 lines of nested `walker --dmenu` + case
dispatch) rebuilt on **fuzzel** (decision recorded: we keep fuzzel; walker's only
real win is image previews — not worth a GTK4 daemon pair).
- New `writeShellScriptBin "ferro-menu"` in a new `home/ferro-menu.nix`:
  `menu() { printf '%s\n' "$@" | fuzzel --dmenu --config ~/.config/fuzzel/ferro.ini -p "$1" }`
  with glyph-prefixed entries and `case` dispatch.
- Submenus (start small, grow): **Go** (launch-or-focus pinned apps) · **Capture**
  (screenshot region/output, OCR→clipboard B6, color picker) · **Style**
  (wallpaper picker — absorbs the existing one-off, toggle gaps B7, screensaver
  now C3) · **Toggle** (idle inhibit, night light, notifications DND) · **System**
  (lock, suspend, relaunch bar, power menu — absorbs existing one-off, `nrs`
  in floating terminal).
- Session-aware where needed: `if [ -n "$NIRI_SOCKET" ]` → `niri msg`, else
  `hyprctl` (same trick the wallpaper script already uses with `|| echo 0,0`).
- Bind `SUPER+ALT+SPACE` in both sessions (niri spawn / hl.bind).
- Extension hook: source `~/.config/ferro-menu.d/*.sh` if present (Omarchy's
  override pattern, simplified).

### B2. tmux upgrade — Omarchy conf merged into `home/tmux.nix`
Steal wholesale (keeps our `C-a` prefix; their `C-Space` rejected — muscle memory):
```tmux
set -g extended-keys on                      # Shift/Ctrl keys reach TUI agents
set -g extended-keys-format csi-u            # (Claude Code under ghostty)
set -g allow-passthrough on
set -g focus-events on
set -g aggressive-resize on
set -g renumber-windows on
set -g detach-on-destroy off                 # killing a session falls into the next
set -g history-limit 50000                   # up from 10000
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'
# prefix-free nav (alongside existing prefix binds, not replacing them)
bind -n M-Enter   split-window -v -c "#{pane_current_path}"
bind -n M-S-Enter split-window -h -c "#{pane_current_path}"
bind -n M-1 ... M-9 select-window -t N
bind -n M-Left/M-Right previous-window/next-window
bind -n M-Up/M-Down switch-client -p/-n
```
Status line: RICE-PLAN 3.3's transparent ferro statusline **plus** Omarchy's mode
indicators on status-right: `#{?pane_in_mode,COPY ,}#{?client_prefix,⌘ ,}#{?window_zoomed_flag,ZOOM ,}`
(prefix indicator already planned; add COPY/ZOOM). Their palette-name trick
(colors as `blue`/`brightblack`) is moot — we interpolate ferro directly.
Also port `omarchy-menu-tmux-keybindings`: `prefix + ?` → `display-popup` running
an awk-generated cheatsheet from the live config (pairs with B8).

### B3. AI dev layouts as fish functions
Port `tdl` / `tds` / `tdlm` / `tsl` to fish (new `home/dev-workflow.nix` or
shell.nix functions), fixing the upstream focus bug (`select-pane` targets the
*editor* pane, not the unset `$opencode_pane`):
- `tdl <ai> [<ai2>]` — editor 70% + AI column 30% + 15% bottom terminal strip;
  window renamed to `basename $PWD`.
- `tds` — 2×2: nvim · live diff watcher · terminal · agent. Their diff pane runs
  `hunk diff --watch` (npm `hunkdiff`); ⚠ VERIFY nixpkgs/npm availability —
  fallback `watch -c -n2 git diff --stat` or `git diff` in delta via entr.
- `tdlm <ai>` — one `tdl` window per subdirectory (multi-repo sweep).
- `tsl <n> <cmd>` — n tiled panes all running the same command (agent swarm).
- Aliases for **our** stack: `ix` = `tdl claude`, `icx` = `tdl claude codex`
  (DHH's fast+slow dual-agent pattern; we have both CLIs). Decide per-invocation
  whether `claude` means bare or `hclaude` (headroom proxy) — make the AI command
  a `$FERRO_AI` env default rather than hardcoding.
  ⚠ DECISION (user): default agent invocation — plain `claude`, `hclaude`, or
  `claude --permission-mode bypassPermissions` (Omarchy's `cx` YOLO default)?
- `t` alias: `tmux attach; or tmux new -s work`, bound to SUPER+ALT+RETURN in
  both sessions via ghostty.

### B4. Git config block (`home/git.nix`)
```nix
diff = { algorithm = "histogram"; colorMoved = "plain"; mnemonicPrefix = true; };
commit.verbose = true;
branch.sort = "-committerdate";
tag.sort = "-version:refname";
rerere = { enabled = true; autoupdate = true; };
column.ui = "auto";
```
(Already have: pull.rebase, autoSetupRemote, gh credential helper, delta.)

### B5. Worktree functions
`ga <branch>` = `git worktree add -b <branch> ../<repo>--<branch>` + cd;
removal fn parses the `repo--branch` convention, removes worktree + force-deletes
branch behind a `gum confirm`. **Rename their `gd` → `gwr`** (worktree-remove);
`gd` is already our `git diff` abbreviation. fish versions; `gum` is in nixpkgs.

### B6. Reminders + OCR (two tiny scripts, zero coupling)
- `ferro-remind <mins> <text>`: `systemd-run --user --on-active=${mins}m`
  → `notify-send -u critical`; `show`/`clear` via `list-timers --output=json | jq`.
  Binds: SUPER+CTRL+R set (fuzzel dmenu input), +ALT show, +SHIFT clear.
- `ferro-ocr`: `grim -g "$(slurp)" - | tesseract stdin stdout | wl-copy` +
  notify. Bind SUPER+CTRL+PRINT. Packages: `tesseract` (+eng data).
Both work identically in both sessions; both get ferro-menu entries.

### B7. Flag-file toggle system
`ferro-toggle <name> [on-cmd] [off-cmd]` + `ferro-toggle-enabled <name>` over
`~/.local/state/ferro/toggles/`. First consumers: screensaver on/off (C3),
gaps on/off (Hyprland: writes a sourced state fragment — remember Omarchy's
lesson: no-gaps must also zero rounding+border; **note** RICE-PLAN explicitly
rejected *smart* gaps — this is a manual toggle, different thing, but default
stays gaps-on), notification DND (`swaync-client -dn` / noctalia equivalent).

### B8. Agent skill + keybinding cheat-sheet
- **NixOS SKILL.md**: Omarchy symlinks a desktop-administration skill into every
  agent's skill dir (`~/.claude/skills/`, `~/.codex/skills/`, `~/.agents/skills/`).
  Ours: a `kronos` skill describing this flake — edit in `~/dotfiles`, `nrs` to
  apply, two-session scoping rules, palette source of truth, never edit
  `~/.config` files that HM owns, verify with `nix build` toplevel before `nrs`.
  Ship via `home.file.".claude/skills/kronos/SKILL.md".source` (+ codex dir).
- **Keybinding cheat-sheet**: binds for both sessions already live in Nix — add
  a `description` field to a binds attrset (future RICE-PLAN refactor) or, v1,
  a generated text list piped to `fuzzel --dmenu` on SUPER+K. Selecting an entry
  executes it (cheat-sheet doubles as command palette).

### B9. Time-boxed passwordless sudo (agent runs)
Port `omarchy-sudo-passwordless`: writes `/etc/sudoers.d/99-ferro-nopasswd`,
transient `systemd-run --on-active=15m` removal, re-run = disable early.
⚠ VERIFY NixOS honors `/etc/sudoers.d` (`security.sudo` generates sudoers with
`@includedir /etc/sudoers.d` only if configured — check `security.sudo.extraConfig`;
if not, declare a NixOS option-based alternative or skip). gum-confirm warning
stays. Useful for long `nrs`-heavy agent sessions.

### B10. launch-or-focus + floating TUI helpers
- `ferro-focus <class> <cmd>`: Hyprland `hyprctl clients -j | jq` / niri
  `niri msg --json windows | jq` → focus if running, else launch. Used by
  ferro-menu Go submenu and app binds.
- `ferro-float-tui <name> <cmd>`: ghostty `--class=TUI.float -e <cmd>` — the
  window rule for `TUI.float` already exists in RICE-PLAN 1.5 (Hyprland); add the
  matching niri window-rule. Used for btop, lazydocker, update terminal.
- Skipped: xdg-terminal-exec indirection — we have exactly one terminal.

### Not porting (workflows)
- **mise / dev-env installers** — direnv + flake templates are the Nix answer.
- **Docker dev-DB script** — nice but trivial to recreate on demand; not config.
- **Voxtype** — we already have `home/dictation.nix`; revisit only to steal the
  F9 push-to-talk + waybar state-indicator pattern if ours lacks it.
- **MCP anything** — Omarchy ships none; our MCP setup is already richer.
- **opencode/pi theme-sync extensions** — niche; our agents run in the themed
  terminal anyway.

---

## Workstream C — Branding, NixOS-flavored

### C1. ASCII pipeline
Vendor Omarchy's `transcode-ascii` approach as `ferro-ascii` (ImageMagick
rasterize → braille/block Unicode; their script is MIT, ~150 lines, no Omarchy
coupling — or `chafa --format symbols`, already-packaged alternative).
Generate two committed artifacts in `home/branding/`:
- `about.txt` — NixOS snowflake in ferro tones (braille render of the snowflake
  SVG, ~54×26), for fastfetch.
- `screensaver.txt` — large "ferro" wordmark or big snowflake for tte.
Ship to `~/.config/ferro/branding/` via xdg.configFile. Regeneration is a
dev-time task, not an activation step.

### C2. About screen — fastfetch
`ferro-about` = launch-or-focus floating TUI running fastfetch with:
logo = branding/about.txt, Hardware box (host/cpu/gpu/display/disk/memory),
Software box (**NixOS generation + flake rev** instead of Omarchy version/channel:
`nixos-version`, `git -C ~/dotfiles log -1 --format=%h`, current specialisation/
session), kernel, wm (niri|Hyprland), package count, **OS age** (their trick:
`(now - stat -c %W /) / 86400` days). Ferro-menu + SUPER+CTRL+A entry.

### C3. Terminal screensaver
Port the chain, both sessions:
- `ferro-screensaver`: loop `tte -i ~/.config/ferro/branding/screensaver.txt
  --random-effect --frame-rate 120 --anchor-canvas c`, exit on keypress/focus loss.
  Package: `terminaltexteffects` ⚠ VERIFY attr name via nixos-mcp.
- `ferro-screensaver-launch`: per-monitor fullscreen ghostty
  `--class=ferro.screensaver --config-file=<minimal opaque config>`;
  Hyprland: `hyprctl monitors -j` + fullscreen window rule;
  niri: `niri msg --json outputs` + `window-rule { match app-id="ferro.screensaver" ... open-fullscreen true }`.
- idle wiring: hypridle gets `timeout 150 → screensaver` ahead of the existing
  300s lock (Omarchy's "screensaver resets idle so lock = half + 2s" hack noted;
  keep our explicit 150/300 instead). niri session: noctalia/swayidle equivalent
  ⚠ check what currently owns idle under niri before adding a second listener.
- `ferro-toggle screensaver` (B7) gates it.
- The minimal screensaver ghostty config sets `background-opacity = 1.0` —
  fully opaque black, no glass, no cursor shader (`custom-shader` unset).

### C4. Boot/login (defer)
Omarchy themes Plymouth/SDDM per theme. RICE-PLAN already scoped tuigreet theming
(4.6) and rejected Plymouth. No change — recorded so we don't re-litigate.

---

## Workstream D — Core-stack tooling (added 2026-06-09; research round 2)

### D1. `programs.claude-code` — flake-manage `~/.claude` (highest leverage)
The HM module now covers settings, hooks, agents, commands, skills, rules,
mcpServers, plugins, marketplaces (+ `enableMcpIntegration` sharing a global
`programs.mcp.servers`). Today's `~/.claude` (20 plugins, GSD hook suite,
ccstatusline, rules/) would not survive a reinstall.
- Migrate incrementally: start with `settings` + `rules` + hooks we author
  (D6); leave plugin-managed files (gsd-*, plugins/) alone until verified the
  module tolerates them.
- **Keep `settings.local.json` mutable** — symlinked settings break Claude's
  self-edits; local stays the escape hatch.
- ⚠ VERIFY module option names against the HM manual at implementation time.
- Tune-up found during research: the vercel-plugin UserPromptSubmit hook
  misfires on nearly every non-Vercel prompt (lexical matches on "workflow",
  "loop", README reads). Scope it per-project or disable globally once
  settings are declarative.

### D2. Nix authoring QoL: nixd + treefmt-nix
- `nixd` LSP configured with `options.nixos.expr` / `home-manager.expr`
  pointed at this flake → autocomplete of our own option set in nvim.
  (nixd is already in `extraPackages`; the win is the per-repo config.)
- `treefmt-nix`: one `nix fmt` for nixfmt+stylua+fish_indent and a free
  `nix flake check` (dotfiles CI in ~10 lines).
- Skipped: flake-parts/import-tree restructure (single-host config, not worth
  the churn yet — revisit if flake.nix gets gnarly), disko/impermanence
  (install-time decisions), nvf/nixvim (LazyVim + mkOutOfStoreSymlink + Nix
  LSPs is already the right hybrid).
- ◐ sops-nix to replace `~/.config/credentials/` chmod-600 dir — separate
  follow-up, touches secrets handling everywhere.

### D3. AI-first nvim — IMPLEMENTED 2026-06-09
Architecture (one tool per layer):
- **0.12 stable** via nixpkgs-unstable overlay (`lib/overlays.nix`) — replaced
  the neovim-nightly overlay, which was locked to a stale pre-0.12.0 build and
  would have jumped to 0.13-dev on update. Input removed from flake.nix.
- **blink.cmp** stays the menu (accept `<CR>`/`<C-y>`, never Tab).
- **Tab autocomplete**: LazyVim extras `ai.copilot-native`
  (vim.lsp.inline_completion, 0.12 native ghost text) + `ai.sidekick`
  (folke's Copilot NES — Cursor-style next-edit suggestions). Tab chain:
  NES jump/apply → ghost-text accept → snippet → literal tab.
  `vim.g.ai_cmp = false` (ghost text mode, no menu source).
- **claudecode.nvim** (coder/) — WebSocket MCP bridge; Claude stays in tmux,
  `/ide` connects it; `<leader>cs/cb/cd/cD` send/context/diff keymaps.
- **Deleted** gen.nvim/ollama (superseded).
First-run: `:Lazy sync`, then `:LspStart copilot` sign-in (`:Copilot auth` /
`:lsp` to inspect). **Pricing decision open**: Copilot Free (2k completions/mo)
to trial; Pro $10/mo for unlimited if it sticks. $0 fallback if it doesn't:
minuet-ai.nvim + Ollama qwen-coder (GPU box makes it viable; quality/latency
step down). supermaven is dead (sunset 2025-11-30); windsurf.nvim = platform
risk after two acquisitions. Skipped: avante/codecompanion (redundant with
Claude-in-the-next-pane), vim.pack (lazy.nvim stays — LazyVim is lazy.nvim),
ui2 (experimental, revisit at 0.13).

### D4. Ghostty 1.3 features
⚠ VERIFY installed ghostty ≥ 1.3 (`ghostty +version`; nixpkgs pin is
2026-03-13, release was 03-09 — close call).
- **Key tables** — native modal keybinds; replaces/upgrades the hand-rolled
  tmux-prefix-mode work from the japandi pass.
- Scrollback search (`ctrl+shift+f`) — free, just don't shadow the bind.
- `notify-on-command-finish` already set; pair with a Stop-hook notify (D6)
  so agent-finished pings work even outside ghostty focus.
- ◐ `shell-integration-features = ssh-terminfo,ssh-env` if SSH use grows.
- Shader discipline: cursor-event shaders only (current warp is fine);
  continuous-animation shaders (CRT/bloom) pin the GPU — rejected.

### D5. pi as second agent
`pi-coding-agent` is in nixpkgs → add to `home/tools.nix`. The fork
**oh-my-pi** (omp, 11.6k★, now bigger than upstream: LSP, debuggers,
hash-anchored edits, worktree subagents) inherits `.claude/` config
(CLAUDE.md, skills) for free but is not in nixpkgs and releases multiple
times a day — run via bun in mutable space if wanted; do not chase its churn
declaratively. Role: overflow/second-opinion agent in a tdl pane.

### D6. Claude Code hooks worth authoring (lands with D1)
1. PostToolUse format-on-edit: treefmt (nixfmt/stylua) on .nix/.lua writes —
   beware self-retrigger; filter on file type and skip when no change.
2. Stop → `notify-send` (works on both sessions' notification daemons).
3. PreToolUse guard: block writes under `~/.config/credentials/`.
Statusline: keep ccstatusline (already configured); ccusage is the analysis
tool, run ad-hoc, not a statusline replacement.

### D7. Local AI loadout — IMPLEMENTED 2026-06-09 (RTX 5070 12GB + 60GB RAM)
`modules/ollama.nix` high tier: **gemma4:12b-it-qat** (daily chat, 7.2 GB QAT —
beats Gemma 3 27B) · **qwen2.5-coder:3b-base** (FIM for minuet fallback;
Qwen3.x chat models are NOT FIM models) · **qwen3.5:4b** (quick jobs).
Container env: flash attention + KV q8_0 + 16K ctx + 30m keep-alive +
max 2 loaded; port now loopback-only. `ai` alias → gemma4.
Follow-ups:
- **Heavy mode — IMPLEMENTED 2026-06-09**: `modules/llama-heavy.nix` —
  llama-server (Docker, CUDA) running Qwen3.6-35B-A3B Q4_K_M with
  `--n-cpu-moe 28` expert offload (~9 GB VRAM + 15 GB RAM, ~20-25 tok/s).
  Not autostarted (owns the GPU); `heavy` / `heavy-stop` fish fns do the
  exclusive swap with the ollama container. Port 8089 loopback, web UI +
  OpenAI-compatible API. Tune --n-cpu-moe down for speed / up if OOM.
  Max-quality upgrade path: Qwen3-Coder-Next 80B-A3B UD-Q4 (~46 GB total)
  in the same container, just a -hf tag change.
- NVFP4 (native Blackwell 4-bit, +~57% prefill in llama.cpp): watch, don't
  switch yet — quality vs Q4_K_M unsettled.
- Old models (qwen3.5:9b, deepseek-r1:14b) still on disk — `ollama rm` when
  satisfied with gemma4.

---

## Workstream E — Dev automation loops (the playbook)

Everything needed is already installed (ralph-loop, GSD, BMAD, codex plugin,
/loop, /schedule). This workstream is *usage doctrine*, not installation.
Five named recipes; the discipline is choosing per task, not running all five.

### E1. "Gate" — daily default: Claude writes, Codex reviews every stop
Enable the codex plugin's stop-time review gate (`codex:setup`), or for big
diffs run Codex manually in the tdl bottom pane: review branch vs main, bugs
only. Cross-provider review is the best-evidenced multi-agent pattern
(different vendors make non-overlapping mistakes). **Cap debate at 2 rounds**;
ignore its style opinions.

### E2. "Phase loop" — structured features: GSD, not BMAD
Per feature: discuss → plan → execute → verify, each phase a fresh session;
`gsd-quick` for small one-shots; `gsd-map-codebase` first on brownfield client
repos. Run token-heavy planning/research phases through `hclaude` (this is the
workload headroom exists for). `gsd-autonomous` only after supervised phases
on that repo. **BMAD verdict**: full pipeline is 5–25× slower for solo-dev
tasks (12min OpenSpec / 90min SpecKit / 5.5hr BMAD benchmark); keep exactly
two pieces — `bmad-code-review` (good adversarial second opinion) and
`bmad-quick-dev` if its style ever beats gsd-quick. One framework per project.

### E3. "Night loop" — unattended grinding, fenced
(User framing 2026-06-09: "Ralph" is legacy branding — these are just loop
automations now, via the Stop-hook loop plugin / `/loop`. Mechanics unchanged.)
Only for mechanically-verifiable batch work (test-coverage expansion,
migrations, greenfield scaffolding from specs). Never judgment work.
1. Prep is 80% of quality: `specs/*.md` (behavioral, one concern per file,
   "one sentence without 'and'"), lean AGENTS.md (build/test commands only).
2. Worktree always (`EnterWorktree` / `git worktree add ../proj-ralph`);
   direnv gives the worktree its dev shell for free. Container if the run
   needs credentials/network beyond the repo.
3. `/ralph-loop "<one-task-per-iteration prompt; tests must pass before
   commit>" --max-iterations 25 --completion-promise "<promise>DONE</promise>"`
4. Morning: read the commit log, then E1 the whole branch before merge.
If it circles: regenerate IMPLEMENTATION_PLAN.md, don't argue with it.
Hard rules: max-iterations always set; no unsandboxed
`--dangerously-skip-permissions` on this machine.

### E4. "Babysitter" — /loop on a pushed PR
Dedicated small tmux pane: `/loop 10m check PR #N: CI failed → diagnose+push
fix; review comment → address; green+approved → tell me`. Scope to one
branch; kill on context switch. Natural fourth pane for the tdl layout.

### E5. "Cron chores" — Routines (cloud) + systemd timer (local)
- Client repos: 1–2 cloud Routines max (weekly dep-audit → draft PR; GitHub
  pull_request trigger → test+review comment). Read-mostly; never auto-merge.
  API rates + $0.08/runtime-hr — fine for minutes-long jobs only.
- Dotfiles: cloud can't `nrs` this box — local `systemd --user` timer running
  `claude -p --bare` for a weekly flake-update review report instead.

### E-skip (recorded so we don't re-litigate)
Full BMAD cast for solo work · any third spec framework (Spec Kit/OpenSpec/
Kiro — pure switching cost) · agent teams >2–3 or swarm-style parallel
writing (solo review capacity caps at ~4 worktrees; teams only for parallel
*investigation*) · Stop hooks that generate responses outside the ralph
plugin (accidental-infinite-loop factory).

---

## Implementation order

Independent of RICE-PLAN's checklist; interleave freely. Ordered by
payoff-per-risk:

- [ ] **N1. Quick wins batch** — B4 git block · B5 worktree fns · B2 tmux conf
      upgrade (extended-keys/csi-u is the Claude-Code-under-tmux fix) · `t` alias
      + SUPER+ALT+RETURN binds. One rebuild, all low-risk.
- [ ] **N2. A1 Inter chrome + A2 hairline tokens + A5 scale comments** — one
      visual pass over waybar/fuzzel/swaync CSS; pairs naturally with RICE-PLAN
      step 5 if done together.
- [ ] **N3. B1 ferro-menu v1** (Go/Capture/System absorbing the existing power +
      wallpaper one-offs) + B10 helpers + A3 fuzzel selection change.
- [ ] **N4. B6 reminders + OCR** + ferro-menu entries.
- [ ] **N5. B3 AI layouts** (tdl/tds/tsl/tdlm as fish fns; resolve the
      $FERRO_AI decision) + B8 SKILL.md.
- [ ] **N6. C1–C3 branding**: ferro-ascii artifacts → fastfetch about → tte
      screensaver + idle wiring + toggle (B7 lands here as its dependency).
- [ ] **N7. A4 hyprlock editorial layout** (with RICE-PLAN 2.5 migration) +
      swaylock approximation.
- [ ] **N8. B7 remaining toggles** (gaps, DND) + B8 cheat-sheet v1 + A6 niri
      open/close motion check.
- [ ] **N9. B9 sudo toggle** (after the sudoers.d verification).

D/E track (interleave with N-track freely; D10 first, it's pure config):

- [ ] **D10. Quick batch** — `pi-coding-agent` to tools.nix · nixd flake config
      (`.nixd.json` or LSP settings in nvim) · treefmt-nix + `nix fmt` +
      flake check · ghostty version check for 1.3 features.
- [ ] **D11. claudecode.nvim** in config/nvim (live symlink — no rebuild).
- [ ] **D12. `programs.claude-code` migration** (settings/rules/authored
      hooks first; plugins later) + D6 hooks + vercel-plugin hook scoping.
- [ ] **D13. Ghostty key tables** (replace hand-rolled prefix mode) once 1.3
      confirmed.
- [ ] **E10. Doctrine, not code**: enable codex stop-gate (`codex:setup`);
      first supervised GSD phase loop on a client repo; first fenced Night
      Ralph on something mechanical; wire the /loop babysitter pane into tdl
      (pairs with B3's layouts).
- [ ] **D14 (later)**: sops-nix credentials migration.

## Decisions (resolved 2026-06-09)

1. **$FERRO_AI default** (B3): `hclaude` (headroom proxy). Verified working —
   see session notes; layouts read `$FERRO_AI`, so per-run override stays one
   env var away.
2. **UI sans** (A1): **Geist** (`geist-font` in nixpkgs — ships Geist Sans +
   Geist Mono; we use the Sans). Everywhere this doc says Inter, read Geist.
3. **Screensaver art** (C1): **NixOS wordmark** in ASCII style (about.txt stays
   the snowflake for fastfetch's square logo slot).
