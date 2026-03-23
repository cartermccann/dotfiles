{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    google-workspace-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    matugen = {
      url = "github:InioX/matugen";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.url = "github:niri-wm/niri?ref=wip/branch";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
    };
    nerd-dictation = {
      url = "github:ideasman42/nerd-dictation";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      google-workspace-cli,
      nixos-hardware,
      matugen,
      niri,
      noctalia,
      ghostty,
      neovim-nightly-overlay,
      nerd-dictation,
      ...
    }:
    let
      mkHost =
        hostname:
        {
          system ? "x86_64-linux",
          user ? "carter",
          extraModules ? [ ],
        }:
        let
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              user
              google-workspace-cli
              matugen
              noctalia
              nerd-dictation
              pkgs-unstable
              ;
          };
          modules = [
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            niri.nixosModules.niri
            (
              { pkgs, ... }:
              {
                nixpkgs.overlays = [
                  niri.overlays.niri
                  (final: prev: { ghostty = ghostty.packages.${prev.system}.default; })
                  neovim-nightly-overlay.overlays.default
                ];
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
                  users.${user} = import ./home/common.nix;
                  extraSpecialArgs = { inherit user google-workspace-cli matugen; };
                  backupFileExtension = "hm-bak";
                };
              }
            )
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations.atlas = mkHost "atlas" {
        extraModules = [ nixos-hardware.nixosModules.microsoft-surface-common ];
      };
      nixosConfigurations.kronos = mkHost "kronos" { user = "cjm"; };

      templates = {
        node = {
          path = ./templates/node;
          description = "Node.js + pnpm + TypeScript";
        };
        python = {
          path = ./templates/python;
          description = "Python 3 + uv";
        };
        elixir = {
          path = ./templates/elixir;
          description = "Elixir + Erlang/OTP";
        };
        zig = {
          path = ./templates/zig;
          description = "Zig";
        };
        go = {
          path = ./templates/go;
          description = "Go";
        };
        ruby = {
          path = ./templates/ruby;
          description = "Ruby";
        };
        java = {
          path = ./templates/java;
          description = "Java (JDK)";
        };
        c = {
          path = ./templates/c;
          description = "C/C++ with gcc, cmake, llvm";
        };
        rust = {
          path = ./templates/rust;
          description = "Rust (rustup)";
        };
        deno = {
          path = ./templates/deno;
          description = "Deno";
        };
      };
    };
}
