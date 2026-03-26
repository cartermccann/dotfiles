{ config, lib, pkgs, nerd-dictation, ... }:

let
  vosk = pkgs.python3Packages.buildPythonPackage rec {
    pname = "vosk";
    version = "0.3.45";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/fc/ca/83398cfcd557360a3d7b2d732aee1c5f6999f68618d1645f38d53e14c9ff/vosk-0.3.45-py3-none-manylinux_2_12_x86_64.manylinux2010_x86_64.whl";
      hash = "sha256-JeAlCTxDmdcnj1Q1aO2MxUYKw6S/SMI2c6zh4l0mYZ8=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    dependencies = with pkgs.python3Packages; [
      cffi
      requests
      tqdm
      srt
      websockets
    ];

    doCheck = false;
  };

  nerd-dictation-pkg = pkgs.python3Packages.buildPythonApplication {
    pname = "nerd-dictation";
    version = "0-unstable";
    src = nerd-dictation;
    format = "other";

    propagatedBuildInputs = [ vosk ];

    installPhase = ''
      runHook preInstall
      install -Dm755 nerd-dictation $out/bin/nerd-dictation
      runHook postInstall
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    nerd-dictation-pkg
    libnotify
    ydotool
    wtype
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
