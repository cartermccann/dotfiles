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
  };

  outputs = { self, nixpkgs, home-manager, google-workspace-cli, ... }:
    let
      mkHost = hostname: { system ? "x86_64-linux", user ? "carter" }:
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
          ];
        };
    in
    {
      nixosConfigurations.atlas = mkHost "atlas" {};
      nixosConfigurations.desktop = mkHost "desktop" { user = "cjm"; };
    };
}
