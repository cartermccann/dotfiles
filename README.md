# dotfiles

NixOS flake for all my machines: Niri + Noctalia (plus two Hyprland session variants: waybar and qs-shell/Quickshell), Ghostty, Neovim, tmux, and a dev-first setup with local LLMs. Built on flake-parts; home-manager runs as a NixOS module.

## Machines

| Host | Hardware | User | Notes |
|------|----------|------|-------|
| **atlas** | Surface Laptop Studio, i7, 32GB RAM | carter | nixos-hardware Surface module, CPU-only Ollama |
| **kronos** | Ryzen 9 9950X, RTX 5070 12GB, 64GB RAM | cjm | LUKS + btrfs, GPU Ollama + llama.cpp heavy mode |

## Usage

```bash
git clone https://github.com/cartermccann/dotfiles ~/dotfiles

# Validate without sudo
nh os build ~/dotfiles

# Apply (or use the `nrs` alias)
sudo nixos-rebuild switch --flake ~/dotfiles#kronos
```

`update` (alias) rebuilds with updated flake inputs.

## Layout

```
flake.nix          # inputs; outputs delegated to parts/
parts/             # flake-parts modules: hosts (mkHost), templates
hosts/             # per-machine configuration + hardware config
modules/           # NixOS system modules (desktop, nvidia, ollama, oom-protection, ...)
home/              # home-manager modules (shell, tools, neovim, tmux, niri, hyprland, ...)
lib/               # overlays + the Ouranos palette (night/day)
pkgs/              # custom package definitions
templates/         # dev-shell templates for `nix flake init -t ~/dotfiles#<lang>`
config/nvim/       # Neovim config, symlinked out of the store so it stays live-editable
scripts/           # shell scripts referenced by modules
docs/              # project specifications, architecture, and delivery plans
wallpaper/
```

## Project documentation

- [Dictation application plan](docs/dictation/README.md)

## Adding a machine

1. Create `hosts/<hostname>/` with a `configuration.nix` (import the modules you need) and the machine's `hardware-configuration.nix`.
2. Register it in `parts/hosts.nix`:
   ```nix
   flake.nixosConfigurations.myhost = mkHost "myhost" { user = "myuser"; };
   ```
3. `sudo nixos-rebuild switch --flake ~/dotfiles#myhost`

## Desktop sessions

- **Hyprland** — primary. Hyprland 0.55 Lua config, two tiles: "Hyprland" (waybar, the daily driver) and "Hyprland (QS)" (qs-shell/Quickshell); `home/hyprland.nix` + `lib/palette.nix`.
- **Niri (Noctalia)** — kept as a working fallback; config in `home/niri-noctalia.nix`. The standalone plain-Niri session was retired and its login tile is filtered out in `modules/desktop-wayland.nix`.

All sessions share ghostty, tmux, the shared Wayland base in `modules/desktop-wayland.nix`, and the helper scripts in `home/niri.nix`.

Colours come from `lib/palette.nix` — **Ouranos**, cobalt on near-black (`night`)
or near-white (`day`), named for the sky Atlas holds up and the father Kronos
was born to. Both variants are always defined; `active` picks which one the
session components get. qs-shell and Caelestia do their own theming and are
deliberately not wired to it.

## Local LLMs

Ollama runs in a podman container (`modules/ollama.nix`); models are preloaded per host tier via `local.ollamaTier`:

| Tier | Hardware | Models |
|------|----------|--------|
| **high** | 12GB VRAM | gemma4:12b-it-qat, Qwythos-9B, qwen2.5-coder:3b, qwen3.5:4b |
| **medium** | CPU, 32GB RAM | qwen3.5:4b, llama3.2:3b |
| **low** | smaller | llama3.2:3b |

`heavy` / `heavy-stop` (fish functions) swap the GPU between Ollama and a llama.cpp server running Qwen3.6-35B MoE with expert offload (`modules/llama-heavy.nix`).

## Dev shells

Per-language templates live in `templates/` and auto-activate via direnv:

```bash
nix flake init -t ~/dotfiles#python   # node, python, go, rust, elixir, zig, java, c, ruby, deno
echo "use flake" > .envrc && direnv allow
```

Shell aliases and fish functions are defined in `home/shell.nix`.
