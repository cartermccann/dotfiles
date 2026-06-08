{
  config,
  lib,
  pkgs,
  ...
}:

# Hermes Agent (NousResearch) runtime toolchain.
#
# Hermes is intentionally self-updating: its installer git-clones into
# ~/.hermes/hermes-agent, builds a uv venv, and writes new skills/memory to
# itself at runtime. So we do NOT package it as a derivation — we just provide
# the toolchain it expects on PATH and let it self-manage ~/.hermes.
#
# Already provided elsewhere (so deliberately omitted here):
#   - uv, ripgrep, python3 (3.13), nodejs_24  -> home/tools.nix
#   - git                                     -> modules/common.nix (systemPackages)
#   - programs.nix-ld + Electron/Chromium libs -> modules/common.nix
#     (needed for the locally-built `hermes desktop` Electron shell and any
#      uv-fetched / Playwright binaries to link on NixOS)
{
  home.packages = with pkgs; [
    # Hermes pins Python 3.11; uv needs a real 3.11 interpreter to build its
    # venv. lowPrio so its python3/python symlinks defer to the global python3
    # (3.13) from tools.nix — only the unique `python3.11` binary is exposed.
    (lib.lowPrio python311)

    ffmpeg # audio/video handling for voice + media features
    electron # runtime for the `hermes desktop` Electron app

    # Knowledge/vault/document tooling Hermes can rely on from Telegram/cron.
    zk # fast local-first markdown note index/search
    markdownlint-cli2 # keep generated vault markdown clean
    vale # prose/style linting for docs + client content
    ocrmypdf # OCR scanned PDFs before ingestion
    poppler-utils # pdftotext/pdfinfo utilities used by ingestion scripts
    pandoc # document format conversion fallback
    # Docling would be useful, but its current nixpkgs dependency docling-parse is marked broken.
    # Use `uvx docling ...` ad hoc until nixpkgs catches up.
  ];

  home.sessionVariables = {
    # Force uv to use the Nix-provided python3.11 instead of downloading a
    # python-build-standalone interpreter.
    UV_PYTHON_DOWNLOADS = "never";
    HERMES_HOME = "${config.home.homeDirectory}/.hermes";
  };

  # The upstream `hermes gateway install` service writes a conventional FHS PATH
  # into ~/.config/systemd/user/hermes-gateway.service. On NixOS that drops the
  # real system/user profiles, so terminal tools inside Telegram lose basics like
  # coreutils (`mkdir`, `cat`) plus Home Manager packages (`bat`, `rg`, `direnv`).
  # Keep Hermes self-managed, but declaratively override the service environment
  # so gateway-spawned tool calls see the same developer toolchain as a normal
  # NixOS shell.
  xdg.configFile."systemd/user/hermes-gateway.service.d/10-nixos-path.conf" = {
    force = true;
    text = ''
      [Service]
      Environment="PATH=${config.home.homeDirectory}/.hermes/hermes-agent/venv/bin:${config.home.homeDirectory}/.hermes/hermes-agent/node_modules/.bin:${config.home.homeDirectory}/.vite-plus/0.1.19/bin:${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.npm-global/bin:/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    '';
  };
}
