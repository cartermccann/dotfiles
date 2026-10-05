# Cursor pinned ahead of nixpkgs (nixpkgs code-cursor lags upstream releases).
# Vendored from nixpkgs pkgs/by-name/co/code-cursor (26.05, buildVscode), Linux-only.
# To bump: get the new URL from
#   curl -s "https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
# then `nix store prefetch-file <url>` and update sources.json.
{
  lib,
  buildVscode,
  fetchurl,
  appimageTools,
  commandLineArgs ? "",
}:

let
  sourcesJson = lib.importJSON ./sources.json;
  source = fetchurl { inherit (sourcesJson.sources.x86_64-linux) url hash; };
  finalCommandLineArgs = "--update=false " + commandLineArgs;
in
(buildVscode rec {
  inherit (sourcesJson) version vscodeVersion;
  useVSCodeRipgrep = false;
  commandLineArgs = finalCommandLineArgs;

  pname = "cursor";

  executableName = "cursor";
  longName = "Cursor";
  shortName = "cursor";
  libraryName = "cursor";
  iconName = "cursor";

  src = appimageTools.extract {
    inherit pname version;
    src = source;
  };
  sourceRoot = "${pname}-${version}-extracted/usr/share/cursor";

  tests = { };
  updateScript = null;

  # Cursor has no wrapper script.
  patchVSCodePath = false;

  meta = {
    description = "AI-powered code editor built on vscode";
    homepage = "https://cursor.com";
    changelog = "https://cursor.com/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cursor";
  };
}).overrideAttrs
  (oldAttrs: {
    autoPatchelfIgnoreMissingDeps = (oldAttrs.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
      "libc.musl-*.so.*" # musl-based node modules are not used on glibc systems
    ];
    preFixup = (oldAttrs.preFixup or "") + ''
      sed -i '/^Keywords=/a MimeType=application/x-cursor-workspace;' \
        $out/share/applications/cursor.desktop
    '';
    postInstall = (oldAttrs.postInstall or "") + ''
      install -Dm644 ../mime/packages/cursor-workspace.xml -t $out/share/mime/packages
      rm -f $out/lib/cursor/resources/appimageupdatetool.AppImage
    '';
  })
