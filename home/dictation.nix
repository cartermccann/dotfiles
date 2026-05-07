{ pkgs, pkgs-unstable, user, ... }:

let
  homeAbs = "/home/${user}";
  shareDir = "${homeAbs}/.local/share/parakeet-dictation";
  modelDir = "${shareDir}/sherpa-model";
  stateDir = "${homeAbs}/.local/state/parakeet-dictation";

  modelUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2";
  modelTopdir = "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8";
in
{
  home.file.".local/bin/setup-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      MODEL_DIR="${modelDir}"
      mkdir -p "$(dirname "$MODEL_DIR")"

      if [ -f "$MODEL_DIR/encoder.int8.onnx" ]; then
        echo "Model already present at $MODEL_DIR"
        exit 0
      fi

      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT

      echo "Downloading Parakeet TDT 0.6B v2 int8 (~480 MB)…"
      ${pkgs.curl}/bin/curl -L --fail --progress-bar \
        -o "$TMP/model.tar.bz2" \
        "${modelUrl}"

      echo "Extracting…"
      ${pkgs.gnutar}/bin/tar -xjf "$TMP/model.tar.bz2" -C "$TMP"
      mv "$TMP/${modelTopdir}" "$MODEL_DIR"

      echo "Model installed at $MODEL_DIR"
    '';
  };

  home.file.".local/bin/toggle-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      export YDOTOOL_SOCKET=/run/ydotoold/socket
      MODEL_DIR="${modelDir}"
      STATE_DIR="${stateDir}"
      WAV="$STATE_DIR/recording.wav"
      RECPID="$STATE_DIR/recorder.pid"

      mkdir -p "$STATE_DIR"

      notify() {
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone-symbolic -t 2000 "Dictation" "$1" || true
      }

      # Auto-fetch model on first run
      if [ ! -f "$MODEL_DIR/encoder.int8.onnx" ]; then
        notify "Fetching model (~480 MB)…"
        if ! "$HOME/.local/bin/setup-dictation.sh"; then
          notify "Model download failed"
          exit 1
        fi
      fi

      if [ -f "$RECPID" ] && kill -0 "$(cat "$RECPID")" 2>/dev/null; then
        # ── STOP path ────────────────────────────────────────────────
        kill -INT "$(cat "$RECPID")" 2>/dev/null || true
        wait "$(cat "$RECPID")" 2>/dev/null || true
        rm -f "$RECPID"
        notify "Transcribing…"

        # sherpa-onnx-offline prints diagnostics + a JSON-ish line per file.
        # The text is on the line beginning with two spaces and "text" (the
        # CLI uses `text  : <result>` after the wav filename).
        TEXT=$(${pkgs-unstable.sherpa-onnx}/bin/sherpa-onnx-offline \
            --tokens="$MODEL_DIR/tokens.txt" \
            --encoder="$MODEL_DIR/encoder.int8.onnx" \
            --decoder="$MODEL_DIR/decoder.int8.onnx" \
            --joiner="$MODEL_DIR/joiner.int8.onnx" \
            --model-type=nemo_transducer \
            --num-threads=4 \
            "$WAV" 2>&1 \
          | ${pkgs.gawk}/bin/awk '
              # Sherpa prints a JSON object on one line containing "text":"…"
              match($0, /"text"[[:space:]]*:[[:space:]]*"[^"]*"/) {
                s = substr($0, RSTART, RLENGTH)
                sub(/^"text"[[:space:]]*:[[:space:]]*"/, "", s)
                sub(/"$/, "", s)
                print s
                exit
              }
            ' || true)

        if [ -n "$TEXT" ]; then
          printf '%s' "$TEXT" | ${pkgs.ydotool}/bin/ydotool type --file -
          notify "Done"
        else
          notify "No transcription"
        fi
      else
        # ── START path ───────────────────────────────────────────────
        ${pkgs.pipewire}/bin/pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
        echo $! > "$RECPID"
        notify "Listening…"
      fi
    '';
  };
}
