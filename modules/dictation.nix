{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libnotify
    ydotool
    wtype
    socat        # toggle script talks to worker over UNIX socket
    sox          # convenience for audio inspection
  ];

  # nix-ld libraries needed for PyTorch / NeMo wheels installed via uv venv
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    bzip2
    xz
    openssl
    libGL
    glib
    libsndfile
    ffmpeg
    libxcrypt-legacy
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
