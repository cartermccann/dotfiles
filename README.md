# dotfiles

NixOS flake config for all my machines. Niri (Wayland tiling compositor), Ghostty, Neovim, and a dev-first setup with local LLMs.

## Machines

| Host | Hardware | User | Notes |
|------|----------|------|-------|
| **atlas** | Surface Laptop Studio, i7, 32GB RAM | carter | CPU-only Ollama, Broadcom WiFi, nixos-hardware Surface module |
| **kronos** | Ryzen 9 9950X, RTX 5070 12GB, 64GB RAM | cjm | LUKS + btrfs, CUDA Ollama, snapper snapshots |

## Quick start

```bash
# Clone
git clone https://github.com/cartermccann/dotfiles ~/dotfiles

# Build for your host
sudo nixos-rebuild switch --flake ~/dotfiles#atlas
sudo nixos-rebuild switch --flake ~/dotfiles#kronos

# Or use the alias
rebuild
```

## Adding a new machine

1. Create `hosts/<hostname>/configuration.nix` — import the modules you need
2. Run `nixos-generate-config` on the machine and save `hardware-configuration.nix`
3. Add it to `flake.nix`:
   ```nix
   nixosConfigurations.myhost = mkHost "myhost" { user = "myuser"; };
   ```
4. `sudo nixos-rebuild switch --flake ~/dotfiles#myhost`

## Structure

```
flake.nix                           # Entry point — mkHost helper, all inputs
├── hosts/
│   ├── atlas/                      # Surface Laptop Studio
│   │   ├── configuration.nix       # Broadcom WiFi, CPU Ollama, Surface kernel override
│   │   └── hardware-configuration.nix
│   └── kronos/                     # Desktop workstation
│       ├── configuration.nix       # LUKS, btrfs, NVIDIA, CUDA Ollama, snapper
│       └── hardware-configuration.nix
├── modules/                        # Shared NixOS modules (pick what you need)
│   ├── common.nix                  # Boot, networking, SSH, fonts, base packages
│   ├── desktop-niri.nix            # Niri compositor + greetd + Wayland stack
│   ├── nvidia.nix                  # RTX 5070, open drivers, CUDA
│   ├── ollama.nix                  # Tiered model preloading (high/medium/low)
│   ├── audio.nix                   # PipeWire + EasyEffects
│   ├── bluetooth.nix               # Bluetooth + bluetui
│   ├── printing.nix                # CUPS + Avahi mDNS
│   ├── networking.nix              # Tailscale + firewall + LocalSend
│   ├── snapper.nix                 # btrfs snapshot automation
│   ├── dev.nix                     # Languages, tools, Docker, Google Workspace CLI
│   ├── dictation.nix               # ydotool + wtype for speech-to-text
│   ├── media.nix                   # Spotify, Tidal, OBS, mpv, kdenlive
│   └── apps.nix                    # Chrome, Slack, Nautilus
├── home/                           # Home Manager modules
│   ├── common.nix                  # Imports all home modules, parameterized user
│   ├── shell.nix                   # Bash + Starship + fzf + zoxide + direnv + aliases
│   ├── ghostty.nix                 # Ghostty terminal (Nord theme)
│   ├── neovim.nix                  # Neovim + LSPs (symlinked config)
│   ├── niri.nix                    # Niri keybinds, Waybar, Mako, Fuzzel
│   ├── tmux.nix                    # Tmux (vim keys, Nord, wl-copy)
│   ├── git.nix                     # Git + delta
│   ├── dictation.nix               # nerd-dictation toggle script + VOSK setup
│   └── openclaw.nix                # OpenClaw gateway service + config merge
├── config/nvim/                    # Neovim config (symlinked from home)
└── wallpaper/
```

## Ollama tiers

Models are auto-pulled on first boot based on `local.ollamaTier` set in each host config:

| Tier | When | Models |
|------|------|--------|
| **high** | 12GB+ VRAM, 64GB+ RAM | qwen3.5:9b, qwen3.5:4b, deepseek-r1:14b |
| **medium** | 32GB RAM, CPU-only | qwen3.5:4b, llama3.2:3b |
| **low** | 16GB or less | llama3.2:3b |

## OpenClaw

Gateway runs as a systemd user service. Config is merged from `home/openclaw/config.json` (committed) + `~/.openclaw/secrets.json` (local, not committed).

```bash
# Set up secrets on a new machine
cp ~/.openclaw/secrets.json.example ~/.openclaw/secrets.json
# Fill in your API keys, then rebuild or re-login to trigger activation
```

LLM router tiers: simple → qwen3.5:4b (local), medium → qwen3.5:9b (local), complex → Claude Sonnet (cloud), reasoning → Claude Opus (cloud).

## Key bindings (Niri)

| Key | Action |
|-----|--------|
| Super + Return | Ghostty |
| Super + Space | Fuzzel launcher |
| Super + H/J/K/L | Focus left/down/up/right |
| Super + Shift + H/J/K/L | Move window |
| Super + 1-0 | Workspaces 1-10 |
| Super + Tab | Next workspace |
| Super + W / Q | Close window |
| Super + F | Maximize |
| Super + Shift + F | Fullscreen |
| Super + T | Toggle floating |
| Super + C | Center column |
| Super + Ctrl + X | Toggle dictation |
| Super + Ctrl + A/B/T | Audio / Bluetooth / Btop |
| Super + , | Dismiss notification |
| Super + Shift + / | Show all keybinds |

## Shell aliases

```bash
rebuild     # nixos-rebuild switch for current host
nrs         # same as rebuild
update      # rebuild with --upgrade
ai          # ollama run qwen3.5:9b
claw        # openclaw
dev         # tmux dev layout (nvim + 2 panes)
gs/ga/gc/gp # git shortcuts
ls/ll       # eza with icons
cat         # bat
grep        # ripgrep
```
