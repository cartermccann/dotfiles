{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  addDriverRunpath,
  alsa-lib,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  krb5,
  libdrm,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  systemd,
  vulkan-loader,
  xorg,
  zlib,
}:

# Grok Bot desktop agent (xAI's Bot, built by Anysphere on the Cursor codebase).
#
# Source is Nichokas/grokbot-linux-port: a verbatim tarball of xAI's official
# Linux .deb (linux-x64). Still a supply-chain tradeoff — unsigned prebuilt
# from a personal GitHub release, pinned by hash below. Bump `version` and
# `hash` together to move it; assets are at
# https://github.com/Nichokas/grokbot-linux-port/releases
# The archive layout since 0.55.0 is `payload/` (Electron app) plus `hicolor/`
# (icons). Older releases put both at the tarball root.
#
# The vendored Electron and the app's native .node modules are upstream
# prebuilts, so autoPatchelf rewrites their interpreter and NEEDED libs, and the
# launcher hands the dlopen'd ones (GTK portals, libsecret, PipeWire, GL) an
# LD_LIBRARY_PATH. Unfree: needs nixpkgs.config.allowUnfree, already set in
# modules/common.nix.
let
  # dlopen'd at runtime rather than NEEDED, so autoPatchelf cannot see them:
  # they have to be on LD_LIBRARY_PATH as well as in buildInputs.
  runtimeLibs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    krb5 # libgssapi_krb5, for SPNEGO/Negotiate proxies
    libdrm
    libGL
    libgbm
    libnotify
    libpulseaudio
    libsecret # Electron safeStorage keyring backend
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pciutils # libpci, GPU probing
    pipewire # screen capture + WebRTC
    systemd # libudev
    vulkan-loader
    zlib
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libxshmfence
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "grok-bot";
  version = "0.58.0";

  src = fetchurl {
    url = "https://github.com/Nichokas/grokbot-linux-port/releases/download/v${finalAttrs.version}/Grok_Bot_${finalAttrs.version}_linux_x64.tar.gz";
    hash = "sha256-dnzwGXFuQPNd+vAnWtHR3WO7R06rbT1gcx4roPX47vo=";
  };

  sourceRoot = "Grok_Bot_${finalAttrs.version}_linux_x64";

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  # Chromium's optional natives (and any leftover helpers) should not fail
  # the patchelf pass if a NEEDED lib is missing from buildInputs.
  autoPatchelfIgnoreMissingDeps = true;

  installPhase = ''
    runHook preInstall

    app=$out/libexec/grok-bot
    mkdir -p "$app"
    cp -r payload/. "$app/"

    mkdir -p $out/share/icons
    cp -r hicolor $out/share/icons/

    # Hand-written launcher instead of makeWrapper: two of the three things it
    # sets are conditional, and makeWrapper cannot add flags conditionally.
    mkdir -p $out/bin
    cat > $out/bin/grok-bot <<EOF
    #!${stdenv.shell}
    export LD_LIBRARY_PATH=${lib.makeLibraryPath runtimeLibs}:${addDriverRunpath.driverLink}/lib\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}

    # Chromium prefers its unprivileged-userns sandbox, which works on this
    # kernel; the setuid helper is only reachable when
    # security.chromiumSuidSandbox.enable is on, and pointing at a store path
    # that cannot be setuid would make Chromium refuse to start.
    if [ -e /run/wrappers/bin/__chrome-sandbox ]; then
      export CHROME_DEVEL_SANDBOX=/run/wrappers/bin/__chrome-sandbox
    fi

    # Hyprland's class is the Wayland app_id. Electron ignores Chromium's
    # --class flag and derives the id from productName ("Grok Bot") or a
    # hyphenated slug. CHROME_DESKTOP is Chromium's desktop-file identity and
    # is the one override that still has a chance of making the class
    # grok-bot; micro-herdr also matches "Grok Bot" if it does not stick.
    export CHROME_DESKTOP=grok-bot.desktop

    # Same gate nixpkgs' own Electron wrappers use, so an X11 session is
    # unaffected.
    ozone=
    if [ -n "\''${NIXOS_OZONE_WL:-}" ] || [ "\''${XDG_SESSION_TYPE:-}" = wayland ]; then
      ozone="--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"
    fi

    exec "$app/grok-bot" --class=grok-bot \$ozone "\$@"
    EOF
    chmod +x $out/bin/grok-bot

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "grok-bot";
      exec = "grok-bot %U";
      icon = "grok-bot";
      desktopName = "Grok Bot";
      comment = "Grok Bot desktop agent";
      categories = [
        "Development"
        "Utility"
      ];
      # Must match the Wayland app_id / WM_CLASS the window actually emits.
      # Official grokbot-linux-port .desktop files use grok-bot; Electron may
      # still report "Grok Bot" (space) which micro-herdr aliases.
      startupWMClass = "grok-bot";
    })
  ];

  meta = {
    description = "Grok Bot desktop agent (third-party Linux port of the prebuilt Electron app)";
    homepage = "https://docs.x.ai/grok-bot";
    downloadPage = "https://github.com/Nichokas/grokbot-linux-port/releases";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok-bot";
  };
})
