#!/usr/bin/env bash
# Launch the real-time Ceen ASCII wallpaper on a Hyprland/wlroots output.
#   renderer (Rust) --rawvideo--> FIFO --> mpvpaper (mpv layer-shell)
# mpvpaper + ffmpeg + systemd-run are put on PATH by the Nix wrapper; CEEN_BIN
# points at the wrapped renderer (which already knows its font + hand clip).
#
# mpvpaper leaks memory on a long-running rawvideo feed — frames pile up outside
# the demuxer/vd queues, so the queue-size flags alone don't bound total RSS
# (observed ~22GiB after a day). We instead (a) pace playback to FPS instead of
# --untimed, (b) run mpvpaper in its own systemd scope with a hard memory
# ceiling (CEEN_MEMMAX, default 2G, no swap) so a runaway OOM-kills only the
# wallpaper, never the box, and (c) supervise the renderer + mpvpaper pair,
# respawning whichever side dies. Switching to a still image
# (hypr-wallpaper-pick) kills this supervisor, which stops the respawn.
#
# Usage: ceen-live-wallpaper [OUTPUT] [WIDTH] [HEIGHT] [FPS]
set -euo pipefail

OUTPUT="${1:-HDMI-A-1}"
WIDTH="${2:-2560}"
HEIGHT="${3:-1440}"
FPS="${4:-60}"

BIN="${CEEN_BIN:-ceen-live}"
FIFO="${XDG_RUNTIME_DIR:-/tmp}/ceen-live.fifo"
MEMMAX="${CEEN_MEMMAX:-2G}"

SINK="" REND=""
cleanup() {
  [ -n "$SINK" ] && kill "$SINK" 2>/dev/null || true
  [ -n "$REND" ] && kill "$REND" 2>/dev/null || true
  rm -f "$FIFO"
}
trap cleanup EXIT
trap 'exit 0' INT TERM

# One renderer+mpvpaper generation against a fresh FIFO. Returns when either
# side exits; the supervisor loop below decides whether to respawn.
run_once() {
  rm -f "$FIFO"; mkfifo "$FIFO"

  # mpvpaper runs in a transient user scope with a hard memory ceiling, so the
  # known leak OOM-kills only the wallpaper (then we respawn) — never the system.
  # --collect garbage-collects the scope on exit so the next spawn is clean.
  systemd-run --user --scope --collect --quiet \
    -p MemoryMax="$MEMMAX" -p MemorySwapMax=0 \
    -- mpvpaper -o "no-audio --no-correct-pts --demuxer=rawvideo \
      --demuxer-rawvideo-w=$WIDTH --demuxer-rawvideo-h=$HEIGHT \
      --demuxer-rawvideo-mp-format=rgb24 --demuxer-rawvideo-fps=$FPS \
      --cache=no --demuxer-max-bytes=48MiB --demuxer-max-back-bytes=0 \
      --vd-queue-max-bytes=32MiB --vd-queue-max-samples=4 \
      --vo=gpu --hwdec=no" "$OUTPUT" "$FIFO" &
  SINK=$!

  # Let the sink open the FIFO read end before we start writing.
  sleep 2

  "$BIN" --width "$WIDTH" --height "$HEIGHT" --fps "$FPS" > "$FIFO" &
  REND=$!

  # Wake when either side exits, then tear the other down so the next
  # generation starts from a clean slate (fresh FIFO, fresh scope).
  wait -n "$SINK" "$REND" 2>/dev/null || true
  kill "$SINK" "$REND" 2>/dev/null || true
  wait "$SINK" "$REND" 2>/dev/null || true
  SINK="" REND=""
}

# Supervise: respawn on death, with a short backoff to avoid a hot crash loop.
# Killing this script (hypr-wallpaper-pick / session exit) stops the loop.
while true; do
  run_once
  sleep 2
done
