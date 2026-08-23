{
  config,
  pkgs,
  pkgs-unstable,
  comcreate-desktop-app,
  google-workspace-cli,
  fenix,
  herdr,
  hermes-agent,
  ...
}:
let
  rustToolchain = fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.withComponents [
    "cargo"
    "clippy"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "rust-src"
  ];

  screamingFrog = pkgs.callPackage ../pkgs/screaming-frog-seo-spider { };
  grokCli = pkgs.callPackage ../pkgs/grok-cli { };
  grokBot = pkgs.callPackage ../pkgs/grok-bot { };
  codexCli = pkgs-unstable.callPackage ../pkgs/codex { };

  comcreateDesktopUpstream =
    comcreate-desktop-app.packages.${pkgs.stdenv.hostPlatform.system}.default;
  comcreateDesktop = pkgs.symlinkJoin {
    name = "comcreate-desktop";
    paths = [ comcreateDesktopUpstream ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/comcreate-desktop" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libayatana-appindicator ]}" \
        --prefix GIO_EXTRA_MODULES : "${pkgs.glib-networking}/lib/gio/modules" \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0" \
        --set-default GDK_BACKEND x11 \
        --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    '';
  };

  # electron_42 comes from unstable because Granola 7.488.3 ships Electron
  # 42.7.0 and unstable's is 42.7.1; stable 25.11 is still on 42.4.0. Same
  # major either way, so the ABI holds, but stay as close as the channel allows.
  granola = pkgs.callPackage ../pkgs/granola {
    electron = pkgs-unstable.electron_42-bin;
  };
in

{
  home.packages = with pkgs; [
    # Languages & runtimes
    python3
    uv
    go
    nodejs_24
    bun
    pnpm
    deno
    nodePackages.typescript
    biome
    rustToolchain

    # CLI staples
    # Kept despite zero interactive history: rg/fd/jq/yq are what coding agents
    # reach for constantly, and atuin only records what *you* type.
    ripgrep
    fd
    jq
    yq
    tree
    eza
    dust # backs the "Disk Usage" desktop entry in home/common.nix
    tree-sitter
    yazi
    glow # markdown reader; referenced by home/hyprland.nix
    gum # shell prompts/confirm (gwr worktree fn, menu scripts)
    procs # modern ps; used by home/codex-desktop.nix

    # Dev workflow
    lazygit
    lazydocker # backs the "Docker" desktop entry in home/common.nix
    git-lfs
    bruno # Git-friendly API client (GUI — usage not visible in shell history)

    # Networking
    netcat-openbsd

    # Cloud & deploy
    flyctl
    google-cloud-sdk # GA4/GSC/BigQuery client work

    # Nix tooling
    nh
    nixfmt-rfc-style
    nix-output-monitor

    # AI / LLM
    pkgs-unstable.opencode # agent CLIs move too fast for stable
    pkgs-unstable.bubblewrap # PATH bwrap preferred by Codex over its bundled fallback
    codexCli
    pkgs-unstable.ollama # CLI client only (server is the podman container) — unstable to stay near the 0.30.x server API
    grokCli # official xAI Grok CLI (grok/agent) — prebuilt binary in ../pkgs/grok-cli
    grokBot # Grok Bot desktop agent — third-party Linux port, see ../pkgs/grok-bot
    pkgs-unstable.cursor-cli # Cursor CLI (binary is `cursor-agent`) — unfree prebuilt, tracks lab releases

    # Meetings & notes
    granola # macOS build repacked onto nixpkgs Electron, see ../pkgs/granola

    # Media & recording
    # obs-studio lives in modules/media.nix (system-level) — it was declared in
    # both, so this copy was redundant.
    yt-dlp

    # SEO
    screamingFrog # proprietary crawler, bundled JDK

    # Rice — trimmed to the ones that are actually wired to something.
    # Dropped (zero invocations, nothing references them): pipes-rs, cbonsai,
    # asciiquarium, sl, lolcat, peaclock, tty-clock.
    cava # rice-dashboard pane; bound to mod+CTRL+D in home/hyprland.nix
    cmatrix
    figlet # required by scripts/comcreate-banner.sh (runs on every bash shell)

    # From flake inputs
    comcreateDesktop
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default # gws
    herdr.packages.${pkgs.stdenv.hostPlatform.system}.default # workspace manager for AI agents
    hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop # Hermes Desktop (Electron)
  ];
}
