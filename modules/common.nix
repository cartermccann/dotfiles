{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.systemd-boot.memtest86.enable = true; # RAM test from boot menu (hold Space at boot)
  boot.loader.timeout = 0; # hold Space to show boot menu

  # Plymouth — Catppuccin boot splash (override Stylix's default theme)
  boot.plymouth = {
    enable = true;
    theme = lib.mkForce "catppuccin-macchiato";
    themePackages = [
      (pkgs.catppuccin-plymouth.override { variant = "macchiato"; })
    ];
  };

  # Quiet boot — hide kernel/systemd noise behind Plymouth
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];

  # Networking
  networking.networkmanager.enable = true;

  # Locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Hyprland's binary cache — without this the pinned 0.55.x flake build
    # compiles from source (heavy; risks OOM on this host).
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  # Runtime libs for prebuilt/dynamically-linked binaries run via nix-ld.
  # Covers the locally-built `hermes desktop` Electron shell (Chromium) and
  # any uv-fetched interpreters or Playwright Chromium.
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    glib
    nss
    nspr
    # Electron / Chromium runtime
    atk
    at-spi2-atk
    at-spi2-core
    cups
    dbus
    expat
    libdrm
    gtk3
    pango
    cairo
    gdk-pixbuf
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxshmfence
    mesa
    libGL
    libxkbcommon
    alsa-lib
    systemd
  ];

  # Symlink /bin/bash for FHS compatibility (e.g. Claude Code plugin hooks)
  system.activationScripts.binbash = ''
    ln -sfn /run/current-system/sw/bin/bash /bin/bash
  '';

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Passwordless rebuilds — lets coding agents apply config after validating
  # with `nh os build`. Scoped to nixos-rebuild only; note this is still
  # effectively root for anything that can write to ~/dotfiles.
  security.sudo.extraRules = [
    {
      users = [ user ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # SSH — key-only auth
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    git
    gh
    wget
    curl
    htop
    btop
    unzip
    file
    killall
    pid-fan-controller

  ];

  # Fish (needed at system level for login shell)
  programs.fish.enable = true;

  # Firefox
  programs.firefox.enable = true;
}
