{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  zlib,
  freetype,
  fontconfig,
  alsa-lib,
  libGL,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  xorg,
}:

# Screaming Frog SEO Spider — proprietary Swing/AWT crawler, shipped only as a
# fat .deb (no tarball) bundling its own JDK 25. We extract the .deb, autoPatchelf
# the vendored JRE against the Nix store, and keep the upstream launcher so the
# user's ~/.screamingfrogseospider memory-tuning file (default -Xmx2g) still works.
# Unfree: requires nixpkgs.config.allowUnfree (already set in modules/common.nix).
let
  runtimeLibs = [
    stdenv.cc.cc.lib # libstdc++ / libgcc_s
    zlib
    freetype
    fontconfig
    alsa-lib
    libGL
    # GTK look-and-feel + native file chooser are dlopen'd at runtime (not NEEDED),
    # so they must be on LD_LIBRARY_PATH as well as in buildInputs.
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
    xorg.libXrandr
    xorg.libXxf86vm
    xorg.libxcb
    xorg.libXau
    xorg.libXdmcp
  ];
in
stdenv.mkDerivation rec {
  pname = "screaming-frog-seo-spider";
  version = "24.2";

  src = fetchurl {
    url = "https://download.screamingfrog.co.uk/products/seo-spider/screamingfrogseospider_${version}_amd64.deb";
    hash = "sha256-XWx54uM8AsZhYb72nVub5bC6eOHAmAmZf14Nn3+kvI0=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  # The vendored JDK dlopens a few genuinely-optional natives (e.g. libsctp);
  # don't fail the patchelf pass over libraries the GUI never touches.
  autoPatchelfIgnoreMissingDeps = true;

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    app=$out/share/screamingfrogseospider
    mkdir -p $app
    cp -r usr/share/screamingfrogseospider/. $app/
    cp -r usr/share/icons $out/share/icons

    # Repoint the upstream launcher at the store; keep its $HOME/.screamingfrogseospider
    # memory-tuning logic intact, then expose dlopen'd GUI libs via LD_LIBRARY_PATH.
    substituteInPlace usr/bin/screamingfrogseospider \
      --replace-fail "/usr/share/screamingfrogseospider/ScreamingFrogSEOSpider.jar" \
                     "$app/ScreamingFrogSEOSpider.jar" \
      --replace-fail "/usr/share/screamingfrogseospider/jre/" \
                     "$app/jre/"
    install -Dm755 usr/bin/screamingfrogseospider $out/libexec/screamingfrogseospider

    makeWrapper $out/libexec/screamingfrogseospider $out/bin/screaming-frog-seo-spider \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
    ln -s $out/bin/screaming-frog-seo-spider $out/bin/screamingfrogseospider

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "screaming-frog-seo-spider";
      exec = "screaming-frog-seo-spider %f";
      icon = "screamingfrogseospider";
      desktopName = "Screaming Frog SEO Spider";
      comment = "Analysis tool for the SEO professional";
      categories = [
        "Network"
        "GTK"
      ];
      startupWMClass = "uk.co.screamingfrog.seospider.ui.id1754890503";
      mimeTypes = [ "application/screamingfrog.seospider" ];
    })
  ];

  meta = {
    description = "Website crawler for SEO auditing (proprietary, bundled JDK)";
    homepage = "https://www.screamingfrog.co.uk/seo-spider/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "screaming-frog-seo-spider";
  };
}
