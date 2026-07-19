{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  basic-memory,
  google-workspace-cli,
  hermes-agent,
  playwright-cli,
  qmd,
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
let
  # nixpkgs-unstable currently carries the pre-submodule-update hash for
  # CTranslate2 4.8.1. Keep MarkItDown's audio support instead of dropping the
  # dependency while the upstream package catches up.
  ctranslate2Fixed = pkgs-unstable.ctranslate2.overrideAttrs (old: {
    src = old.src.overrideAttrs (_: {
      outputHash = "sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=";
    });
  });

  pythonPackagesFixed = pkgs-unstable.python3Packages.overrideScope (
    _: previous: {
      ctranslate2 = previous.ctranslate2.override {
        ctranslate2-cpp = ctranslate2Fixed;
      };
    }
  );

  basicMemoryCli = pkgs.writeShellApplication {
    name = "bm";
    text = ''
      export UV_PYTHON_DOWNLOADS=never
      # basic-memory's Alembic/aiosqlite startup deadlocks under Python 3.13's
      # nested event loop on NixOS. Python 3.12 is supported upstream and
      # completes migrations deterministically.
      export UV_PYTHON=${pkgs.python312}/bin/python3.12
      export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}:''${LD_LIBRARY_PATH:-}
      exec ${pkgs.uv}/bin/uvx --from basic-memory==0.22.1 bm "$@"
    '';
  };

  githubMcpHermes = pkgs.writeShellApplication {
    name = "github-mcp-hermes";
    text = ''
      token="$(${pkgs.gh}/bin/gh auth token)"
      export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
      export GITHUB_TOOLSETS="default,actions,notifications,projects"
      exec ${pkgs-unstable.github-mcp-server}/bin/github-mcp-server stdio
    '';
  };

  playwrightCli = pkgs-unstable.callPackage ../pkgs/playwright-cli {
    src = playwright-cli;
  };
in
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
    pythonPackagesFixed.markitdown # Office/PDF/email/audio -> Markdown ingestion
    qmd.packages.${pkgs.stdenv.hostPlatform.system}.default # local hybrid search for vault/project docs
    basicMemoryCli # native Hermes graph memory provider, pinned through uvx
    githubMcpHermes # official typed GitHub MCP, reusing the existing gh login
    playwrightCli # deterministic browser automation alongside agent-browser
    # Docling would be useful, but its current nixpkgs dependency docling-parse is marked broken.
    # Use `uvx docling ...` ad hoc until nixpkgs catches up.
  ];

  # Hermes discovers SKILL.md files recursively. Keep large upstream skill
  # catalogs in the Nix store and expose them as single directory symlinks.
  home.file = {
    ".hermes/skills/productivity/google-workspace" = {
      source = "${google-workspace-cli}/skills";
      force = true;
    };
    ".hermes/skills/research/qmd" = {
      source = "${qmd}/skills/qmd";
      force = true;
    };
    ".hermes/skills/browser/playwright-cli" = {
      source = "${playwright-cli}/skills/playwright-cli";
      force = true;
    };
    ".hermes/skills/devops/hermes-ops" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/skills/hermes-ops";
      force = true;
    };
    ".hermes/plugins/basic-memory" = {
      source = "${basic-memory}/integrations/hermes";
      force = true;
    };
    ".hermes/basic-memory.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/config/hermes/basic-memory.json";
      force = true;
    };
  };

  # Keep the collection manifest writable and versioned: qmd's own collection
  # commands can update it, and the resulting change remains visible in git.
  xdg.configFile."qmd/index.yml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/config/qmd/index.yml";
    force = true;
  };

  home.sessionVariables = {
    # Force uv to use the Nix-provided python3.11 instead of downloading a
    # python-build-standalone interpreter.
    UV_PYTHON_DOWNLOADS = "never";
    HERMES_HOME = "${config.home.homeDirectory}/.hermes";
    PLAYWRIGHT_BROWSERS_PATH = "${config.home.homeDirectory}/.cache/ms-playwright";
    PLAYWRIGHT_MCP_EXECUTABLE_PATH = "/run/current-system/sw/bin/google-chrome-stable";
    PLAYWRIGHT_MCP_HEADLESS = "true";
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
      Environment="PATH=${config.home.homeDirectory}/.hermes/hermes-agent/venv/bin:${config.home.homeDirectory}/.hermes/hermes-agent/node_modules/.bin:${config.home.homeDirectory}/.vite-plus/bin:${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.npm-global/bin:/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      Environment="PLAYWRIGHT_BROWSERS_PATH=${config.home.homeDirectory}/.cache/ms-playwright"
      Environment="PLAYWRIGHT_MCP_EXECUTABLE_PATH=/run/current-system/sw/bin/google-chrome-stable"
      Environment="PLAYWRIGHT_MCP_HEADLESS=true"
      ExecReload=
      ExecReload=${pkgs.coreutils}/bin/kill -USR1 $MAINPID
    '';
  };
}
