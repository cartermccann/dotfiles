{
  lib,
  rustPlatform,
  makeWrapper,
  ffmpeg,
  mpvpaper,
  dejavu_fonts,
}:

# Real-time generative ASCII wallpaper (the Ceen signal hand).
# The Rust renderer streams rawvideo to stdout; the wrapped launcher pipes it
# through a FIFO into mpvpaper on the Hyprland background layer.
rustPlatform.buildRustPackage {
  pname = "ceen-live";
  version = "0.1.0";

  src = ./crate;
  cargoLock.lockFile = ./crate/Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];

  # The renderer shells out to ffmpeg (decode) and reads font + clip from env.
  postInstall = ''
    install -Dm644 ${./assets/hand.mp4} $out/share/ceen-live/hand.mp4

    wrapProgram $out/bin/ceen-live \
      --set-default CEEN_FONT ${dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf \
      --set-default CEEN_HAND $out/share/ceen-live/hand.mp4 \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}

    install -Dm755 ${./ceen-live-wallpaper.sh} $out/bin/ceen-live-wallpaper
    wrapProgram $out/bin/ceen-live-wallpaper \
      --set CEEN_BIN $out/bin/ceen-live \
      --prefix PATH : ${lib.makeBinPath [ mpvpaper ffmpeg ]}
  '';

  meta = {
    description = "Real-time generative ASCII wallpaper for Hyprland (Ceen signal hand)";
    mainProgram = "ceen-live-wallpaper";
    platforms = lib.platforms.linux;
  };
}
