{ config, lib, pkgs, ... }:

{
  # Nerd-dictation — offline speech-to-text using VOSK
  environment.systemPackages = with pkgs; [
    nerd-dictation
    vosk-models.small-en-us # VOSK speech model
    libnotify # for notify-send in toggle script
    ydotool # for typing output
    wtype # Wayland text input
  ];

  # ydotool daemon for simulating keyboard input
  services.ydotool.enable = true;
}
