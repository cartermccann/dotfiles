{
  buildNpmPackage,
  lib,
  makeWrapper,
  nodejs_24,
  src,
}:

let
  package = builtins.fromJSON (builtins.readFile "${src}/package.json");
in
buildNpmPackage {
  pname = "playwright-cli";
  inherit (package) version;
  inherit src;

  npmDepsHash = "sha256-u44jWprmr3RdzB3aDL3K0ShT5lLxr175z3C8pN43YFA=";
  nodejs = nodejs_24;
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  installPhase = ''
    runHook preInstall

    install -d "$out/lib/playwright-cli" "$out/bin"
    cp -R package.json playwright-cli.js skillCheck.js node_modules "$out/lib/playwright-cli/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/playwright-cli" \
      --set NO_UPDATE_NOTIFIER 1 \
      --add-flags "$out/lib/playwright-cli/playwright-cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Playwright browser automation CLI for coding agents";
    homepage = "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    mainProgram = "playwright-cli";
    platforms = lib.platforms.linux;
  };
}
