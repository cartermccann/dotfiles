{
  config,
  lib,
  pkgs,
  ...
}:

let
  # User is passed via specialArgs from flake.nix
  user = config.users.users;
in
{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;

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
    zoxide
    pid-fan-controller

  ];

  # Fish (needed at system level for login shell)
  programs.fish.enable = true;

  # Firefox
  programs.firefox.enable = true;
}
