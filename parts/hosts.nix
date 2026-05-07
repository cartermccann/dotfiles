{ inputs, ... }:
let
  mkHost =
    hostname:
    {
      system ? "x86_64-linux",
      user ? "carter",
      extraModules ? [ ],
    }:
    let
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      overlays = import ../lib/overlays.nix { inherit inputs; };
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit
          user
          pkgs-unstable
          ;
        inherit (inputs)
          google-workspace-cli
          noctalia
          zen-browser
          helium
          ;
      };
      modules = [
        ../hosts/${hostname}/configuration.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.niri.nixosModules.niri
        inputs.stylix.nixosModules.stylix
        ../modules/stylix.nix
        (
          { pkgs, ... }:
          {
            nixpkgs.overlays = overlays;
            programs.niri.package = pkgs.niri-unstable.overrideAttrs (old: {
              doCheck = false;
            });
          }
        )
        (
          { pkgs, ... }:
          {
            users.users.${user} = {
              isNormalUser = true;
              shell = pkgs.fish;
              extraGroups = [
                "wheel"
                "docker"
                "networkmanager"
                "input"
              ];
              openssh.authorizedKeys.keys = [
              ];
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${user} = {
                imports = [
                  ../home/common.nix
                ];
              };
              extraSpecialArgs = {
                inherit user pkgs-unstable;
                inherit (inputs) google-workspace-cli fenix;
              };
              backupFileExtension = "hm-bak";
            };
          }
        )
      ]
      ++ extraModules;
    };
in
{
  flake.nixosConfigurations.atlas = mkHost "atlas" {
    extraModules = [ inputs.nixos-hardware.nixosModules.microsoft-surface-common ];
  };
  flake.nixosConfigurations.kronos = mkHost "kronos" { user = "cjm"; };
}
