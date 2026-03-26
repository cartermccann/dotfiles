{
  description = "Rust project";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, fenix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          rust-toolchain = fenix.packages.${system}.stable.withComponents [
            "cargo"
            "clippy"
            "rustc"
            "rustfmt"
            "rust-analyzer"
            "rust-src"
          ];
        in {
          default = pkgs.mkShell {
            packages = [
              rust-toolchain
            ];
          };
        });
    };
}
