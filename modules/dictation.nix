{ pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = [
    pkgs.libnotify
    pkgs.ydotool
    pkgs-unstable.sherpa-onnx
  ];

  # ydotoold needs root for /dev/uinput; socket is group=input so user can reach it
  systemd.services.ydotoold = {
    description = "ydotoold - ydotool daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold/socket --socket-perm=0660";
      RuntimeDirectory = "ydotoold";
      RuntimeDirectoryMode = "0750";
      Restart = "on-failure";
      Group = "input";
    };
  };
}
