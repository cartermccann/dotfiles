{ config, pkgs, user, ... }:

{
  # Dictation toggle script (same as your Omarchy setup)
  home.file.".local/bin/toggle-dictation.sh" = {
    executable = true;
    text = ''
      #!/bin/bash
      if pgrep -f "nerd-dictation begin" > /dev/null; then
        nerd-dictation end
        notify-send "Dictation" "Dictation stopped" -i audio-input-microphone-symbolic -t 2000
      else
        nerd-dictation begin \
          --vosk-model-dir="$HOME/.local/share/nerd-dictation/model" \
          --numbers-as-digits &
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
