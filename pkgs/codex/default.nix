{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  makeBinaryWrapper,
  bubblewrap,
  ripgrep,
  versionCheckHook,
  zstd,
}:

# Codex releases faster than nixpkgs, so package OpenAI's official static
# release bundle directly. Keep the bundle's binaries and resources together:
# Codex resolves codex-code-mode-host and the bundled bwrap relative to itself.
# To update, bump version and both bundle hashes from the matching GitHub release.
let
  version = "0.144.0";
  bundles = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-ETkdAweoXUaTgdRKTDlRfTK+wyu2jTlHyj9yYJNmkok=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-gJIpyLUcnDNnEVt25e/+UmciZCsMpM2Td9sCCVNCafI=";
    };
  };
  bundle =
    bundles.${stdenvNoCC.hostPlatform.system}
      or (throw "codex: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-${bundle.target}-bundle.tar.zst";
    inherit (bundle) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
    zstd
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/codex
    tar --extract \
      --file=$src \
      --use-compress-program=unzstd \
      --directory=$out/libexec/codex

    makeWrapper $out/libexec/codex/codex $out/bin/codex \
      --prefix PATH : ${
        lib.makeBinPath [
          ripgrep
          bubblewrap
        ]
      }

    export HOME=$(mktemp -d)
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames bundles;
  };
})
