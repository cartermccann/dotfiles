{
  config,
  pkgs,
  pkgs-unstable,
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
    ripgrep
    fd
    jq
    yq
    tree
    eza
    dust
    duf # prettier df
    tldr
    tree-sitter
    yazi
    glow # markdown reader
    xh # httpie-style curl
    gum # shell prompts/confirm (gwr worktree fn, menu scripts)
    ouch # universal compress/decompress
    procs # modern ps
    sd # modern sed
    broot # interactive tree/file navigator
    television # general-purpose fuzzy finder TUI
    cht-sh # cheat.sh client

    # Dev workflow
    just # command runner
    watchexec # file watcher
    tokei # code statistics
    hyperfine # CLI benchmarking
    difftastic # syntax-aware diffs
    lazygit
    lazydocker
    git-lfs
    git-bug # issue tracker embedded in git
    posting # terminal API client
    bruno # Git-friendly API client
    rainfrog # Postgres TUI

    # Networking
    whois
    netcat-openbsd
    doggo # DNS lookup
    gping # graphical ping
    bandwhich # per-process bandwidth

    # Cloud & deploy
    flyctl
    stripe-cli
    google-cloud-sdk
    awscli2

    # Nix tooling
    nh
    nixfmt-rfc-style
    nix-output-monitor

    # AI / LLM
    pkgs-unstable.opencode # agent CLIs move too fast for stable — take both from unstable
    pkgs-unstable.codex
    pkgs-unstable.ollama # CLI client only (server is the podman container) — unstable to stay near the 0.30.x server API
    fabric-ai # reusable AI prompt patterns
    grokCli # official xAI Grok CLI (grok/agent) — prebuilt binary in ../pkgs/grok-cli

    # Media & recording
    obs-studio
    yt-dlp

    # SEO
    screamingFrog # proprietary crawler, bundled JDK

    # Rice
    cava
    pipes-rs
    cbonsai
    cmatrix
    asciiquarium
    sl # the train you typo into
    figlet # big ascii banners
    lolcat # rainbow pipe (figlet | lolcat)
    peaclock # zen full-screen terminal clock
    tty-clock # minimal digital clock (tty-clock -c -C 4)

    # From flake inputs
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default # gws
    herdr.packages.${pkgs.stdenv.hostPlatform.system}.default # workspace manager for AI agents
    hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop # Hermes Desktop (Electron)
  ];
}
