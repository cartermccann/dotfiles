{ config, pkgs, user, ... }:

let
  homeAbs = "/home/${user}";
  stateDir = "$HOME/.local/state/parakeet-dictation";
  shareDir = "$HOME/.local/share/parakeet-dictation";
  venvDir = "${shareDir}/venv";
  modelDir = "${shareDir}/models";
  venvAbs = "${homeAbs}/.local/share/parakeet-dictation/venv";
  socketRel = "parakeet-dictation.sock";

  # Pinned PyTorch nightly index for Blackwell sm_120 support; bump as needed
  torchIndex = "https://download.pytorch.org/whl/nightly/cu128";
in
{
  home.file.".local/bin/toggle-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      export YDOTOOL_SOCKET=/run/ydotoold/socket
      STATE_DIR="${stateDir}"
      SOCK="$XDG_RUNTIME_DIR/${socketRel}"
      WAV="$STATE_DIR/recording.wav"
      RECPID="$STATE_DIR/recorder.pid"

      mkdir -p "$STATE_DIR"

      notify() {
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone-symbolic -t 2000 "Dictation" "$1" || true
      }

      if [ -f "$RECPID" ] && kill -0 "$(cat "$RECPID")" 2>/dev/null; then
        # ── STOP path ────────────────────────────────────────────────
        kill -INT "$(cat "$RECPID")" 2>/dev/null || true
        wait "$(cat "$RECPID")" 2>/dev/null || true
        rm -f "$RECPID"
        notify "Transcribing…"

        if [ ! -S "$SOCK" ]; then
          notify "Worker socket missing — is parakeet-dictation.service running?"
          exit 1
        fi

        # Send wav path; receive transcribed text
        TEXT=$(printf '%s\n' "$WAV" | ${pkgs.socat}/bin/socat - UNIX-CONNECT:"$SOCK" || true)
        if [ -n "$TEXT" ]; then
          # ydotool reads from stdin with --file -
          printf '%s' "$TEXT" | ${pkgs.ydotool}/bin/ydotool type --file -
          notify "Done"
        else
          notify "No transcription (empty result)"
        fi
      else
        # ── START path ───────────────────────────────────────────────
        # 16 kHz mono s16 WAV is what NeMo's Parakeet expects natively
        ${pkgs.pipewire}/bin/pw-record --rate 16000 --channels 1 --format s16 "$WAV" &
        echo $! > "$RECPID"
        notify "Listening…"
      fi
    '';
  };

  home.file.".local/bin/parakeet-worker.py" = {
    executable = true;
    text = ''
      #!${venvAbs}/bin/python
      """Persistent Parakeet ASR worker. Loads model once, transcribes WAVs over a unix socket."""
      import os, sys, socket, traceback

      SOCK_PATH = os.path.join(os.environ["XDG_RUNTIME_DIR"], "${socketRel}")
      MODEL_NAME = "nvidia/parakeet-tdt-0.6b-v2"

      print(f"[parakeet-worker] loading {MODEL_NAME} …", flush=True)
      import nemo.collections.asr as nemo_asr
      asr = nemo_asr.models.ASRModel.from_pretrained(MODEL_NAME)
      asr.eval()
      try:
          import torch
          if torch.cuda.is_available():
              asr = asr.to("cuda")
              print(f"[parakeet-worker] on CUDA: {torch.cuda.get_device_name(0)}", flush=True)
      except Exception as e:
          print(f"[parakeet-worker] GPU move failed, staying on CPU: {e}", flush=True)

      def transcribe(wav_path: str) -> str:
          out = asr.transcribe([wav_path], batch_size=1)
          # NeMo returns either list[str] or list[Hypothesis] depending on version
          item = out[0] if out else ""
          text = getattr(item, "text", item)
          return (text or "").strip()

      try:
          os.unlink(SOCK_PATH)
      except FileNotFoundError:
          pass
      srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
      srv.bind(SOCK_PATH)
      os.chmod(SOCK_PATH, 0o600)
      srv.listen(4)
      print(f"[parakeet-worker] ready on {SOCK_PATH}", flush=True)

      while True:
          conn, _ = srv.accept()
          try:
              data = b""
              while not data.endswith(b"\n"):
                  chunk = conn.recv(4096)
                  if not chunk:
                      break
                  data += chunk
              wav = data.decode("utf-8").strip()
              if not wav:
                  conn.sendall(b"")
                  continue
              try:
                  text = transcribe(wav)
              except Exception:
                  traceback.print_exc()
                  text = ""
              conn.sendall(text.encode("utf-8"))
          finally:
              conn.close()
    '';
  };

  home.file.".local/bin/setup-dictation.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      SHARE_DIR="${shareDir}"
      VENV="${venvDir}"
      MODEL_DIR="${modelDir}"

      mkdir -p "$SHARE_DIR" "$MODEL_DIR"

      if [ ! -d "$VENV" ]; then
        echo "Creating uv venv at $VENV …"
        ${pkgs.uv}/bin/uv venv --python 3.12 "$VENV"
      fi

      # Activate venv for pip ops
      # shellcheck disable=SC1091
      source "$VENV/bin/activate"

      echo "Installing PyTorch nightly (cu128 for Blackwell sm_120) …"
      # Pin matching torch + torchaudio nightly date (mismatched dates ABI-break)
      ${pkgs.uv}/bin/uv pip install --python "$VENV/bin/python" \
        --pre --index-url ${torchIndex} \
        "torch==2.12.0.dev20260407" "torchaudio==2.11.0.dev20260407"

      echo "Installing NeMo ASR + audio deps …"
      ${pkgs.uv}/bin/uv pip install --python "$VENV/bin/python" \
        "nemo_toolkit[asr]" \
        soundfile huggingface_hub

      echo "Pre-downloading Parakeet model (~2.4 GB) …"
      HF_HOME="$MODEL_DIR" "$VENV/bin/python" - <<'PY'
import os
os.environ.setdefault("HF_HOME", os.path.expanduser("~/.local/share/parakeet-dictation/models"))
import nemo.collections.asr as nemo_asr
nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt-0.6b-v2")
print("Model downloaded.")
PY

      echo
      echo "Setup complete. Starting worker:"
      echo "  systemctl --user enable --now parakeet-dictation.service"
    '';
  };

  systemd.user.services.parakeet-dictation = {
    Unit = {
      Description = "Parakeet ASR worker for dictation";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "HF_HOME=%h/.local/share/parakeet-dictation/models"
        "PATH=%h/.local/share/parakeet-dictation/venv/bin:/run/current-system/sw/bin:/usr/bin"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib"
      ];
      ExecStart = "%h/.local/bin/parakeet-worker.py";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
