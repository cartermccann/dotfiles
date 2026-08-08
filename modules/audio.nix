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

  # Rank the outputs so the default sink lands on whatever is actually being
  # listened to, in the order they're actually used:
  #
  #   Bluetooth headphones > FIIO SA1 (desk speakers) > Schiit Gunnr > HDMI
  #
  # This matters because volume keys target @DEFAULT_AUDIO_SINK@. If the
  # default is a device nothing is playing on, the OSD moves and the sound
  # doesn't — which is exactly the symptom that prompted this. Without explicit
  # ranking WirePlumber scores by its own heuristics and the default drifts
  # with enumeration order; the GPU's HDMI sink in particular is almost never
  # wanted and is pushed to the bottom.
  #
  # Bluetooth sits above the wired outputs so headphones take over on connect
  # and hand back on disconnect. Nothing is disabled — everything is still
  # selectable in pavucontrol.
  services.pipewire.wireplumber.extraConfig."51-default-sink" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "alsa_output.usb-BAB_FIIO_SA1_20240416905926-00.analog-stereo"; } ];
        actions.update-props."priority.session" = 2000;
      }
      {
        matches = [ { "node.name" = "alsa_output.usb-Schiit_Audio_Schiit_Gunnr-00.analog-stereo"; } ];
        actions.update-props."priority.session" = 1500;
      }
      {
        matches = [ { "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo"; } ];
        actions.update-props."priority.session" = 100;
      }
    ];
    "monitor.bluez.rules" = [
      {
        matches = [ { "device.api" = "bluez5"; } ];
        actions.update-props."priority.session" = 3000;
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
