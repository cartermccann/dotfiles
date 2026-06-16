#!/usr/bin/env bash
# Launch the real-time Ceen ASCII wallpaper on a Hyprland/wlroots output.
#   renderer (Rust) --rawvideo--> FIFO --> mpvpaper (mpv layer-shell)
# mpvpaper + ffmpeg are put on PATH by the Nix wrapper; CEEN_BIN points at the
# wrapped renderer (which already knows its font + hand clip via env).
#
# Usage: ceen-live-wallpaper [OUTPUT] [WIDTH] [HEIGHT] [FPS]
set -euo pipefail

OUTPUT="${1:-HDMI-A-1}"
WIDTH="${2:-2560}"
HEIGHT="${3:-1440}"
FPS="${4:-60}"

BIN="${CEEN_BIN:-ceen-live}"
FIFO="${XDG_RUNTIME_DIR:-/tmp}/ceen-live.fifo"

cleanup() {
  [ -n "${SINK:-}" ] && kill "$SINK" 2>/dev/null || true
  [ -n "${REND:-}" ] && kill "$REND" 2>/dev/null || true
  rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

rm -f "$FIFO"; mkfifo "$FIFO"

mpvpaper -o "no-audio --no-correct-pts --untimed --demuxer=rawvideo \
  --demuxer-rawvideo-w=$WIDTH --demuxer-rawvideo-h=$HEIGHT \
  --demuxer-rawvideo-mp-format=rgb24 --demuxer-rawvideo-fps=$FPS \
  --cache=no --vo=gpu --hwdec=no" "$OUTPUT" "$FIFO" &
SINK=$!

# Let the sink open the FIFO read end before we start writing.
sleep 2

"$BIN" --width "$WIDTH" --height "$HEIGHT" --fps "$FPS" > "$FIFO" &
REND=$!

wait "$REND"
