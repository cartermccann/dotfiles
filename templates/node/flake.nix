{
  description = "Node.js project";
  inputs.nixpkgs.url = "nixpkgs/nixos-25.11";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forEachSystem (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nodejs nodePackages.pnpm nodePackages.typescript
              nodePackages.vercel nodePackages.wrangler bun
            ];
          };
        });
    };
}
