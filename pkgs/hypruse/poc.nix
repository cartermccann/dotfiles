{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [
    p.mcp
    p.pygobject3
  ]);
in
{
  inherit python;
  hypruse = pkgs.callPackage ./. { };
  fixture = pkgs.stdenv.mkDerivation {
    pname = "hypruse-poc-fixture";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.wrapGAppsHook3
      pkgs.gobject-introspection
    ];
    buildInputs = [
      python
      pkgs.gtk3
    ];
    installPhase = ''
      mkdir -p "$out/bin" "$out/share/hypruse-poc"
      cp ${./fixture.py} "$out/share/hypruse-poc/fixture.py"
      makeWrapper ${python}/bin/python "$out/bin/hypruse-poc-fixture" \
        --add-flags "$out/share/hypruse-poc/fixture.py"
    '';
  };
}
