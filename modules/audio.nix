{
  config,
  lib,
  pkgs,
  ...
}:

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

  # Pin the default sink to the Schiit Gunnr USB DAC.
  #
  # Without this, WirePlumber picks by its own priority scoring and the default
  # drifts between the DAC, the FIIO SA1 and the HDMI output depending on what
  # enumerated first. Volume keys target @DEFAULT_AUDIO_SINK@, so a drifting
  # default is a drifting volume key. The HDMI sink in particular is on the
  # GPU and is almost never what's wanted.
  #
  # priority.session is what `wpctl status` sorts on when choosing a default;
  # the two alternates are pushed below the DAC rather than disabled, so they
  # are still selectable in pavucontrol.
  services.pipewire.wireplumber.extraConfig."51-default-sink" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "alsa_output.usb-Schiit_Audio_Schiit_Gunnr-00.analog-stereo"; } ];
        actions.update-props."priority.session" = 2000;
      }
      {
        matches = [ { "node.name" = "alsa_output.usb-BAB_FIIO_SA1_20240416905926-00.analog-stereo"; } ];
        actions.update-props."priority.session" = 1000;
      }
      {
        matches = [ { "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo"; } ];
        actions.update-props."priority.session" = 100;
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    # Installed but deliberately NOT autostarted — see home/niri-noctalia.nix.
    # Running it inserts a virtual sink ahead of the hardware one, which is what
    # made volume keys feel broken. Launch it manually when you want the EQ.
    easyeffects
    pavucontrol
    pamixer
    playerctl
    qpwgraph # PipeWire patchbay
  ];
}
