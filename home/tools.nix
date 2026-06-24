{
  config,
  pkgs,
  google-workspace-cli,
  fenix,
  herdr,
  ...
}:
let
  rust-toolchain = fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.withComponents [
    "cargo"
    "clippy"
    "rustc"
    "rustfmt"
    "rust-analyzer"
    "rust-src"
  ];

  screaming-frog-seo-spider = pkgs.callPackage ../pkgs/screaming-frog-seo-spider { };
in

{
  home.packages = with pkgs; [
    # Languages (globally available)
    python3
    go

    # Modern CLI
    ripgrep
    fd
    jq
    yq
    tree
    eza
    dust
    tldr
    tree-sitter
    yazi
    cava
    glow # markdown reader
    xh # modern httpie
    gum # shell prompts/confirm (gwr worktree fn, ferro-menu scripts)
    ouch # universal compress/decompress
    duf # prettier df
    procs # modern ps
    bandwhich # per-process network bandwidth
    doggo # DNS lookup
    gping # graphical ping

    # Dev workflow tools
    just # command runner
    watchexec # file watcher
    tokei # code statistics
    hyperfine # CLI benchmarking
    sd # modern sed

    # Rice
    pipes-rs
    cbonsai
    cmatrix # green rain — pairs with the ferro phosphor motif
    asciiquarium # terminal aquarium screensaver
    sl # the train you typo into
    figlet # big ascii banners (try: figlet ferro)
    lolcat # rainbow pipe (figlet ferro | lolcat)
    peaclock # zen full-screen terminal clock
    tty-clock # minimal digital clock (tty-clock -c -C 4)

    # Dev workflow
    nodejs_24
    bun
    pnpm
    deno
    nodePackages.typescript
    biome
    lazygit
    lazydocker
    uv
    flyctl
    stripe-cli
    git-lfs
    google-cloud-sdk
    awscli2

    rust-toolchain

    # Nix tooling
    nixfmt-rfc-style
    nh
    nix-output-monitor

    # AI / LLM
    opencode
    codex

    # Recording
    obs-studio

    # SEO
    screaming-frog-seo-spider # `screaming-frog-seo-spider` — proprietary crawler, bundled JDK 25

    # Networking
    whois
    netcat-openbsd

    # Google Workspace CLI
    google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default

    # herdr — terminal workspace manager for AI coding agents
    herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
