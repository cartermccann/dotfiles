{ config, pkgs, user, ... }:

{
  # Dictation toggle script
  home.file.".local/bin/toggle-dictation.sh" = {
    executable = true;
    text = ''
      #!/bin/bash
      export YDOTOOL_SOCKET=/run/ydotoold/socket
      PIDFILE="$HOME/.local/share/nerd-dictation/pid"
      if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        nerd-dictation end
        rm -f "$PIDFILE"
        notify-send "Dictation" "Dictation stopped" -i audio-input-microphone-symbolic -t 2000
      else
        nerd-dictation begin \
          --vosk-model-dir="$HOME/.local/share/nerd-dictation/model" \
          --simulate-input-tool=YDOTOOL \
          --input=PW-CAT \
          --numbers-as-digits &
        echo $! > "$PIDFILE"
        notify-send "Dictation" "Dictation started - speak now" -i audio-input-microphone-symbolic -t 2000
      fi
    '';
  };

  # Setup script to download VOSK model on first run
  home.file.".local/bin/setup-dictation.sh" = {
    executable = true;
    text = ''
      #!/bin/bash
      MODEL_DIR="$HOME/.local/share/nerd-dictation/model"
      if [ ! -d "$MODEL_DIR" ]; then
        echo "Downloading VOSK speech model..."
        mkdir -p "$HOME/.local/share/nerd-dictation"
        cd "$HOME/.local/share/nerd-dictation"
        wget -q https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
        unzip -q vosk-model-small-en-us-0.15.zip
        mv vosk-model-small-en-us-0.15 model
        rm vosk-model-small-en-us-0.15.zip
        echo "VOSK model installed."
      else
        echo "VOSK model already installed."
      fi
    '';
  };
}
