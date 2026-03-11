{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    google-workspace-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, home-manager, google-workspace-cli, nixos-hardware, ... }:
    let
      mkHost = hostname: { system ? "x86_64-linux", user ? "carter", extraModules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit user google-workspace-cli; };
          modules = [
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              # User account
              users.users.${user} = {
                isNormalUser = true;
                extraGroups = [ "wheel" "docker" "networkmanager" "input" ];
                openssh.authorizedKeys.keys = [
                  # Add your public SSH key here
                ];
              };

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = import ./home/common.nix;
                extraSpecialArgs = { inherit user; };
                backupFileExtension = "backup";
              };
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations.atlas = mkHost "atlas" { extraModules = [ nixos-hardware.nixosModules.microsoft-surface-common ]; };
      nixosConfigurations.kronos = mkHost "kronos" { user = "cjm"; };
    };
}
