# dotfiles — NixOS flake

Flake-parts layout. This repo defines the entire system (kronos) + home-manager config.

## Layout

- `flake.nix` / `parts/` — flake outputs (hosts in `parts/hosts.nix`, templates in `parts/templates.nix`)
- `hosts/` — per-machine config
- `modules/` — NixOS system modules (desktop, nvidia, ollama, oom-protection, ...)
- `home/` — home-manager modules (tools, shell, neovim, tmux, niri, hyprland-ferro, headroom, ...)
- `templates/` — `nix flake init -t ~/dotfiles#<lang>` dev-shell templates
- `scripts/`, `config/`, `wallpaper/` — non-Nix assets referenced by modules

## Workflow

1. Edit the relevant module (`home/` for user-level, `modules/` for system-level).
2. Validate without sudo: `nh os build ~/dotfiles` (or `nix flake check ~/dotfiles`).
3. Apply: `sudo nixos-rebuild switch --flake ~/dotfiles#kronos` (passwordless via NOPASSWD rule in `modules/common.nix`). The user's own alias is `nrs` (nh os switch).

## Conventions

- Format Nix files with `nixfmt-rfc-style` (`nixfmt <file>`).
- New home packages go in `home/tools.nix`; system build deps in `modules/dev.nix`.
- Shell aliases/functions live in `home/shell.nix` — keep `~/.claude/rules/nix-environment.md` in sync when they change.
- Never commit `result` symlinks.
- Look up packages/options with the nixos-mcp tools, not memory — nixpkgs moves fast.

## Gotchas

- Desktop sessions: niri+noctalia is primary; "Hyprland (Ferro)" is a second session (`home/hyprland-ferro.nix`). swww owns the wallpaper — Noctalia's wallpaper module is deliberately disabled.
- First rebuild after adding a cachix substituter may prompt for trust — expected.
- uv-tool installs (e.g. headroom-ai) are NOT in this flake; manage with `uv tool upgrade <name>`.
