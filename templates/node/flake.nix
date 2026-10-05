{
  description = "Node.js project";
  inputs.nixpkgs.url = "nixpkgs/nixos-26.05";
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
              # nodePackages is gone in 26.05; vercel left nixpkgs with it
              # (use `pnpm dlx vercel`).
              nodejs pnpm typescript wrangler bun
            ];
          };
        });
    };
}
