{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHost = hostname: { system ? "x86_64-linux", user ? "carter" }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = import ./home/common.nix;
                backupFileExtension = "backup";
              };
            }
          ];
        };
    in
    {
      nixosConfigurations.atlas = mkHost "atlas" {};
    };
}
