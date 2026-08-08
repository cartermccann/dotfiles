{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  glib,
  gtk3,
  gdk-pixbuf,
  cairo,
  pango,
  webkitgtk_4_1,
  libsoup_3,
  openssl,
  pipewire,
  libpulseaudio,
  alsa-lib,
  wayland,
  libayatana-appindicator,
  librsvg,
  gsettings-desktop-schemas,
  desktop-file-utils,
  xdg-utils,
  xorg,
}:

# Anarlog (ex-Hyprnote) — local-first AI meeting notetaker, the open-source
# Granola equivalent. Tauri app (webkitgtk 4.1) shipped only as .deb/.dmg/.exe
# and AppImage; we extract the .deb and autoPatchelf it against the store.
#
# Two things are load-bearing here:
#   * WEBKIT_DISABLE_DMABUF_RENDERER=1 — without it the webview renders black
#     on Wayland + proprietary Nvidia, which is exactly kronos.
#   * libpipewire/libpulse on LD_LIBRARY_PATH — the recorder pulls system audio
#     through them, and they are dlopen'd rather than NEEDED in some paths.
#   * desktop-file-utils on PATH — the deep-link plugin shells out to
#     `update-desktop-database` during setup and aborts the whole app if it is
#     missing, so the window never appears without it.
#
# Transcription models (Whisper/Parakeet) are NOT bundled; the app downloads
# them into ~/.local/share on first use.
let
  # dlopen'd at runtime, so they must be on LD_LIBRARY_PATH as well as in
  # buildInputs — autoPatchelf alone will not find them.
  runtimeLibs = [
    stdenv.cc.cc.lib
    glib
    gtk3
    gdk-pixbuf
    cairo
    pango
    webkitgtk_4_1
    libsoup_3
    openssl
    pipewire
    libpulseaudio
    alsa-lib
    wayland
    libayatana-appindicator # tray icon
    librsvg # symbolic icons in the tray/menus
    xorg.libX11
    xorg.libXi
  ];

  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-mbN1Njjgo7qnww1SiPJg/3r4z00Y2IdbnO4UxCRTlnY=";
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-GnJn2BFhDOdDCNtfxxjDja5dtQbf4l1roMt4Ohw8XnU=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "anarlog: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "anarlog";
  version = "1.4.5";

  src = fetchurl {
    url = "https://github.com/fastrepl/anarlog/releases/download/desktop_v${finalAttrs.version}/anarlog-linux-${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = runtimeLibs ++ [ gsettings-desktop-schemas ];

  # onnxruntime (statically linked) probes for optional execution providers —
  # libonnxruntime_providers_{cuda,rocm,tensorrt,...}.so. None ship in the .deb
  # and the CPU provider is what we use, so don't fail the patchelf pass.
  autoPatchelfIgnoreMissingDeps = true;

  unpackPhase = "dpkg-deb -x $src .";

  # wrapGAppsHook3 would wrap the binaries before we add LD_LIBRARY_PATH; defer
  # it so both sets of flags land on one wrapper.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec $out/share
    cp -r usr/share/applications $out/share/applications
    cp -r usr/share/icons $out/share/icons
    cp -r usr/lib/Anarlog $out/share/anarlog

    for prog in anarlog anarlog-cli char-chrome-native-host; do
      install -Dm755 usr/bin/$prog $out/libexec/$prog
    done

    runHook postInstall
  '';

  postFixup = ''
    for prog in anarlog anarlog-cli char-chrome-native-host; do
      makeWrapper $out/libexec/$prog $out/bin/$prog \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
        --prefix PATH : "${
          lib.makeBinPath [
            desktop-file-utils
            xdg-utils
          ]
        }" \
        --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    done
  '';

  meta = {
    description = "Local-first AI meeting notetaker (open-source Granola alternative)";
    homepage = "https://github.com/fastrepl/anarlog";
    changelog = "https://anarlog.so/changelog/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "anarlog";
  };
})
