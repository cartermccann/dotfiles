{ config, lib, pkgs, ... }:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Swap — gives headroom for LLMs
  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4GB
  }];

  # Networking
  networking.networkmanager.enable = true;

  # Locale
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
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

  # Docker
  virtualisation.docker.enable = true;

  # Ollama — local LLM server
  services.ollama = {
    enable = true;
    acceleration = false; # no GPU, CPU-only
  };

  # User
  users.users.carter = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      # Add your public SSH key here before rebuilding
    ];
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
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
  ];

  # Firefox
  programs.firefox.enable = true;
}
