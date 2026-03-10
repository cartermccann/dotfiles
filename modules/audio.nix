{ config, lib, pkgs, ... }:

{
  # PipeWire — full audio stack
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # EasyEffects for audio processing
  environment.systemPackages = with pkgs; [
    easyeffects
    pavucontrol
    pamixer
    playerctl
    qpwgraph # PipeWire patchbay
  ];
}
