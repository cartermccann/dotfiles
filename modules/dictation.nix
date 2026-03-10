{ config, lib, pkgs, ... }:

{
  # Dictation tools
  environment.systemPackages = with pkgs; [
    libnotify # for notify-send in toggle script
    ydotool # for typing output
    wtype # Wayland text input
  ];

  # ydotool daemon for simulating keyboard input
  systemd.services.ydotoold = {
    description = "ydotoold - ydotool daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
    };
  };
}
