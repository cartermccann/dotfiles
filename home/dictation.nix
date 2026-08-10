{
  pkgs,
  pkgs-unstable,
  user,
  ...
}:

# Two dictation modes, sharing one setup script and one state dir:
#
#   live  (Mod+Alt+L)        streaming model, types words as you speak
#   batch (Mod+Alt+Shift+L)  offline model, types the whole utterance at the end
#
# Live is the daily driver. Batch is kept because the offline model is the more
# accurate of the two on a finished utterance and runs at RTF 0.02, which is
# worth having for a long dictation where latency doesn't matter.
#
# Chunk size for the streaming model was chosen by measurement, not by picking
# the lowest published latency. On an idle machine the 560 ms model is fine
# (RTF 0.69), but under load (16 busy cores) it goes to 1.20 — past real time,
# where the transcript falls progressively behind speech and never recovers.
# The 1120 ms model holds 0.38 under that same load with no accuracy loss on
# the test clip, so it is the one that survives dictating while something
# compiles. The 240 ms model cannot hold real time on this box at all (1.30
# idle) and a CUDA build of onnxruntime does not help: streaming ASR is
# latency-bound on a serial chain of tiny chunks, so the GPU sat at 18%
# utilisation and came out slower than CPU.
let
  homeAbs = "/home/${user}";
  shareDir = "${homeAbs}/.local/share/parakeet-dictation";
  modelDir = "${shareDir}/sherpa-model";
  streamModelDir = "${shareDir}/sherpa-model-streaming";
  stateDir = "${homeAbs}/.local/state/parakeet-dictation";

  releaseBase = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models";
  modelTopdir = "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8";
  streamTopdir = "sherpa-onnx-nemo-parakeet-unified-en-0.6b-int8-streaming-1120ms";

  pythonEnv = pkgs-unstable.python313.withPackages (ps: [
    ps.sherpa-onnx
    ps.numpy
  ]);
in
{
  home.file.".local/bin/dictation-stream.py".text = ''
    #!/usr/bin/env python3
    # Reads raw s16le mono 16 kHz PCM on stdin (from pw-record --raw) and types
    # each newly recognised token as it lands.
    #
    # Typing only the delta is safe because greedy transducer decoding emits
    # tokens monotonically: the token list is append-only and never retracted,
    # so tokens[n:] is exactly the text not yet typed. This was verified against
    # the 1120 ms model before the approach was committed to. A beam-search
    # decoder revises earlier tokens, so switching decoding_method away from
    # greedy_search would corrupt whatever window has focus.
    import os
    import queue
    import subprocess
    import sys
    import threading

    import numpy as np
    import sherpa_onnx

    MODEL = os.environ["DICTATION_STREAM_MODEL"]
    YDOTOOL = os.environ.get("DICTATION_TYPE_CMD", "ydotool")
    SAMPLE_RATE = 16000
    # 0.2 s per read, well under the model's 1120 ms chunk, so the recogniser
    # never waits on us for input.
    READ_BYTES = int(SAMPLE_RATE * 0.2) * 2

    # ydotool's defaults are --key-delay 20 --key-hold 20, i.e. 40 ms of
    # sleeping per character, or 25 characters/second. Speech runs about 15
    # characters/second, so at stock settings typing alone eats ~60% of real
    # time — and decoding takes another ~38% once the machine is busy. That
    # sums to over 100%, which is the whole bug: see the threading note below.
    # 10 ms/char leaves the hold well clear of event coalescing while giving
    # ~7x headroom over speech.
    TYPE_ARGS = ["type", "--key-delay", "2", "--key-hold", "8", "--file", "-"]

    # Typing runs on its own thread so ydotool can never stall the reader.
    #
    # It used to be called inline from the read loop, which meant every
    # millisecond spent typing was a millisecond not spent draining the pipe
    # from pw-record. On an idle machine that just fit; under load it did not,
    # and the deficit compounds: the pipe backs up, pw-record blocks on write,
    # PipeWire drops the capture it cannot hand over, and the transcript falls
    # permanently behind and then dries up. Measured on kronos with 14 busy
    # cores and a looped 7.4 s clip, stock ydotool timing: 10 s behind after
    # 2 minutes and still growing. With typing removed from the loop the same
    # run held 0 s of lag. That is why this looked like a one-minute time
    # limit — nothing was timing out, the pipeline was losing a race.
    _typeq = queue.SimpleQueue()


    def _type(text):
        if YDOTOOL == "-":  # dry-run harness
            sys.stdout.write(text)
            sys.stdout.flush()
            return
        subprocess.run([YDOTOOL, *TYPE_ARGS], input=text.encode(), check=False)


    def _typist():
        while True:
            item = _typeq.get()
            done = item is None
            parts = [] if done else [item]
            # Drain whatever else is already waiting into a single ydotool run:
            # both the process spawn and the per-key timing amortise, and the
            # deltas arriving here are often only a token or two wide.
            while not done:
                try:
                    nxt = _typeq.get_nowait()
                except queue.Empty:
                    break
                if nxt is None:
                    done = True
                else:
                    parts.append(nxt)
            if parts:
                try:
                    _type("".join(parts))
                except Exception as exc:  # never take the thread down silently
                    print(f"dictation: type failed: {exc}", file=sys.stderr, flush=True)
            if done:
                return


    def emit(text):
        if text:
            _typeq.put(text)


    def flush(recognizer, stream, typed, fresh_segment):
        tokens = recognizer.get_result_all(stream).tokens
        if len(tokens) <= typed:
            return typed, fresh_segment
        text = "".join(tokens[typed:])
        if fresh_segment and text and not text[0].isspace():
            text = " " + text
        emit(text)
        return len(tokens), False


    def main():
        recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
            tokens=f"{MODEL}/tokens.txt",
            encoder=f"{MODEL}/encoder.int8.onnx",
            decoder=f"{MODEL}/decoder.int8.onnx",
            joiner=f"{MODEL}/joiner.int8.onnx",
            num_threads=4,
            provider="cpu",
            decoding_method="greedy_search",
            enable_endpoint_detection=True,
        )
        stream = recognizer.create_stream()
        typed = 0
        fresh_segment = False
        stdin = sys.stdin.buffer

        typist = threading.Thread(target=_typist, name="typist")
        typist.start()

        while True:
            data = stdin.read(READ_BYTES)
            if not data:
                break
            if len(data) % 2:  # partial frame at EOF
                data = data[:-1]
            pcm = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768
            stream.accept_waveform(SAMPLE_RATE, pcm)
            while recognizer.is_ready(stream):
                recognizer.decode_stream(stream)

            typed, fresh_segment = flush(recognizer, stream, typed, fresh_segment)

            if recognizer.is_endpoint(stream):
                recognizer.reset(stream)
                typed = 0
                # The first token after a reset may lack the leading space that
                # normally separates words, which would run the next sentence
                # into the previous one.
                fresh_segment = True

        stream.input_finished()
        while recognizer.is_ready(stream):
            recognizer.decode_stream(stream)
        flush(recognizer, stream, typed, fresh_segment)

        # Toggling off closes the pipe, so this is the exit path for a normal
        # stop: hand the thread its sentinel and wait, or the tail of the last
        # sentence dies with the process.
        _typeq.put(None)
        typist.join()


    if __name__ == "__main__":
        main()
  '';

  home.file.".local/bin/setup-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      fetch() {
        local dir="$1" topdir="$2" label="$3"
        if [ -f "$dir/encoder.int8.onnx" ]; then
          echo "$label already present at $dir"
          return 0
        fi
        mkdir -p "$(dirname "$dir")"
        local tmp
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' RETURN

        echo "Downloading $label (~480 MB)…"
        ${pkgs.curl}/bin/curl -L --fail --progress-bar \
          -o "$tmp/model.tar.bz2" \
          "${releaseBase}/$topdir.tar.bz2"

        echo "Extracting…"
        ${pkgs.gnutar}/bin/tar -xjf "$tmp/model.tar.bz2" -C "$tmp"
        mv "$tmp/$topdir" "$dir"
        echo "$label installed at $dir"
      }

      fetch "${streamModelDir}" "${streamTopdir}" "Parakeet streaming 1120ms"
      fetch "${modelDir}" "${modelTopdir}" "Parakeet TDT 0.6B v2 (offline)"
    '';
  };

  # The live pipeline, split out of the toggle so the toggle doesn't have to
  # nest quoting three deep. pw-record's PID is published so the toggle can
  # stop *it* rather than the whole group: killing the recorder closes the pipe,
  # which lets the client flush its last tokens and exit on EOF. Killing the
  # group instead would drop the tail of the final sentence.
  home.file.".local/bin/dictation-live.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -uo pipefail

      STATE_DIR="${stateDir}"
      RECPID="$STATE_DIR/recorder.pid"
      mkdir -p "$STATE_DIR"

      export YDOTOOL_SOCKET=/run/ydotoold/socket
      export DICTATION_STREAM_MODEL="${streamModelDir}"
      export DICTATION_TYPE_CMD="${pkgs.ydotool}/bin/ydotool"

      {
        ${pkgs.pipewire}/bin/pw-record --raw \
          --rate 16000 --channels 1 --format s16 --latency 100ms - 2>/dev/null &
        echo $! > "$RECPID"
        wait $!
      } | ${pythonEnv}/bin/python3 "$HOME/.local/bin/dictation-stream.py"

      rm -f "$RECPID"
    '';
  };

  home.file.".local/bin/toggle-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      STATE_DIR="${stateDir}"
      RECPID="$STATE_DIR/recorder.pid"
      mkdir -p "$STATE_DIR"

      notify() {
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone-symbolic -t 2000 \
          -h string:x-canonical-private-synchronous:dictation "Dictation" "$1" || true
      }

      # Stale state from a previous session: nrs or a reboot can leave the pid
      # file behind, or the PID can be recycled by something unrelated.
      if [ -f "$RECPID" ]; then
        PID=$(cat "$RECPID" 2>/dev/null || true)
        if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
          rm -f "$RECPID"
        elif ! grep -q pw-record "/proc/$PID/comm" 2>/dev/null; then
          rm -f "$RECPID"
        fi
      fi

      if [ -f "$RECPID" ] && kill -0 "$(cat "$RECPID")" 2>/dev/null; then
        # Stop the recorder only; the client flushes its tail on EOF.
        kill -INT "$(cat "$RECPID")" 2>/dev/null || true
        notify "Off"
        exit 0
      fi

      if [ ! -f "${streamModelDir}/encoder.int8.onnx" ]; then
        notify "Fetching streaming model (~480 MB)…"
        if ! "$HOME/.local/bin/setup-dictation.sh"; then
          notify "Model download failed"
          exit 1
        fi
      fi

      # ~1.7 s of that is loading the model; deliberately not prewarmed, since a
      # resident daemon would hold ~600 MB all day for an occasional dictation.
      notify "Listening…"
      # Kept to a log rather than /dev/null: when the live pipeline misbehaves
      # it does so mid-session with nothing attached to its stderr, and a
      # silent >/dev/null is why the ydotool starvation above took a
      # reproduction harness to find instead of a glance at a file.
      setsid "$HOME/.local/bin/dictation-live.sh" \
        >"$STATE_DIR/live.log" 2>&1 </dev/null &
    '';
  };

  # The original batch flow: record to a wav, transcribe once you stop, type the
  # result in one go. Slower to first word, but the offline model is the more
  # accurate of the two.
  home.file.".local/bin/toggle-dictation-batch.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      export YDOTOOL_SOCKET=/run/ydotoold/socket
      MODEL_DIR="${modelDir}"
      STATE_DIR="${stateDir}"
      WAV="$STATE_DIR/recording.wav"
      RECPID="$STATE_DIR/batch-recorder.pid"

      mkdir -p "$STATE_DIR"

      notify() {
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone-symbolic -t 2000 \
          -h string:x-canonical-private-synchronous:dictation "Dictation (batch)" "$1" || true
      }

      if [ ! -f "$MODEL_DIR/encoder.int8.onnx" ]; then
        notify "Fetching model (~480 MB)…"
        if ! "$HOME/.local/bin/setup-dictation.sh"; then
          notify "Model download failed"
          exit 1
        fi
      fi

      if [ -f "$RECPID" ]; then
        STALE_PID=$(cat "$RECPID" 2>/dev/null || true)
        if [ -z "$STALE_PID" ] || ! kill -0 "$STALE_PID" 2>/dev/null; then
          rm -f "$RECPID" "$WAV"
        elif ! grep -q pw-record "/proc/$STALE_PID/comm" 2>/dev/null; then
          rm -f "$RECPID" "$WAV"
        fi
      fi

      if [ -f "$RECPID" ] && kill -0 "$(cat "$RECPID")" 2>/dev/null; then
        STOP_PID=$(cat "$RECPID")
        kill -INT "$STOP_PID" 2>/dev/null || true
        # `wait` only works on direct children, so poll until pw-record exits
        # (and finishes flushing the wav header) before transcribing.
        for _ in $(seq 1 30); do
          kill -0 "$STOP_PID" 2>/dev/null || break
          sleep 0.1
        done
        rm -f "$RECPID"
        notify "Transcribing…"

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
          # Same timing argument as the live path: at stock 40 ms/char a long
          # batch utterance takes longer to type out than it took to say.
          printf '%s' "$TEXT" \
            | ${pkgs.ydotool}/bin/ydotool type --key-delay 2 --key-hold 8 --file -
          notify "Done"
        else
          notify "No transcription"
        fi
      else
        ${pkgs.pipewire}/bin/pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
        echo $! > "$RECPID"
        notify "Listening…"
      fi
    '';
  };
}
