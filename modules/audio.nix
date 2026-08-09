{
  config,
  lib,
  pkgs,
  ...
}:

let
  fiioNode = "alsa_output.usb-BAB_FIIO_SA1_20240416905926-00.analog-stereo";
  schiitNode = "alsa_output.usb-Schiit_Audio_Schiit_Gunnr-00.analog-stereo";
  hdmiNode = "alsa_output.pci-0000_01_00.1.hdmi-stereo";

  # ---------------------------------------------------------------------------
  # Speech bus — see the block near the bottom of this file for the full
  # rationale. These names are shared between the sink definition and the
  # routing rules, which live in three different PipeWire config files.
  # ---------------------------------------------------------------------------
  speechBusNode = "speech-bus";

  # Applications whose output is human speech, and therefore worth
  # transcribing. Everything NOT listed here — Spotify, Tidal, games, system
  # sounds — keeps going straight to the default sink and is never captured.
  # This is an allowlist on purpose: a new music player should be silent to
  # anarlog by default, not require a rule to become silent.
  #
  # Matching is by regex ("~" prefix). Both keys are checked because the two
  # families disagree about which one is meaningful, and because Nix's wrapper
  # scripts rename binaries — Spotify reports ".spotify-wrapped", not
  # "spotify", so anything matching on the binary alone is fragile.
  speechAppMatches = [
    { "application.process.binary" = "~.*(firefox|zen|chrome|chromium|helium|brave).*"; }
    { "application.name" = "~.*([Ff]irefox|[Zz]en|[Cc]hrome|[Cc]hromium|[Hh]elium|[Bb]rave).*"; }
  ];

  # anarlog's system-audio capture stream, whose PipeWire client name is
  # "anarlog-speaker-capture". It calls pw_stream_connect with no target, which
  # is precisely why it lands on the default sink's monitor and hears whatever
  # is playing, music included. anarlog exposes a microphone picker but no
  # output picker, and its only use of @DEFAULT_SINK@ is an unrelated headphone
  # check, so there is no in-app setting for this. Retargeting the stream from
  # outside is what makes the whole split work.
  anarlogCaptureRule = {
    matches = [
      { "application.name" = "~.*anarlog.*"; }
      { "node.name" = "~.*anarlog.*"; }
      { "application.process.binary" = "~.*anarlog.*"; }
    ];
    actions.update-props = {
      "target.object" = speechBusNode;
      # Capture the sink's monitor rather than a source. anarlog already sets
      # this itself; repeating it keeps the rule correct if that ever changes.
      "stream.capture.sink" = true;
    };
  };

  # ---------------------------------------------------------------------------
  # HiFiMan Arya Stealth correction — oratory1990, ported verbatim from
  # config/audio/Arya_Stealth_oratory1990.json (the EasyEffects export).
  #
  # The preset's left and right channels are byte-identical, so one mono chain
  # replicated across FL/FR reproduces it exactly. EasyEffects applies the
  # -5.1 dB as *output* gain; the chain is linear and time-invariant and runs in
  # float, so putting it first as a preamp is mathematically the same response
  # and matches the AutoEQ convention.
  #
  # EasyEffects' "APO (DR)" band mode is the Audio EQ Cookbook biquad, which is
  # what PipeWire's bq_* builtins implement — so Freq/Gain/Q transfer 1:1 with
  # no reinterpretation.
  # ---------------------------------------------------------------------------
  aryaPreampMult = 0.555904; # 10 ^ (-5.1 / 20)

  aryaBands = [
    {
      label = "bq_lowshelf";
      freq = 105.0;
      gain = 5.9;
      q = 0.7;
    }
    {
      label = "bq_peaking";
      freq = 99.0;
      gain = -2.5;
      q = 0.31;
    }
    {
      label = "bq_peaking";
      freq = 150.0;
      gain = 0.2;
      q = 1.75;
    }
    {
      label = "bq_peaking";
      freq = 652.0;
      gain = 0.8;
      q = 4.18;
    }
    {
      label = "bq_peaking";
      freq = 969.0;
      gain = -1.3;
      q = 3.17;
    }
    {
      label = "bq_peaking";
      freq = 1373.0;
      gain = 0.9;
      q = 4.21;
    }
    {
      label = "bq_peaking";
      freq = 1825.0;
      gain = 5.1;
      q = 1.78;
    }
    {
      label = "bq_peaking";
      freq = 3009.0;
      gain = -2.8;
      q = 3.29;
    }
    {
      label = "bq_peaking";
      freq = 4828.0;
      gain = -3.9;
      q = 4.18;
    }
    {
      label = "bq_highshelf";
      freq = 10000.0;
      gain = -3.1;
      q = 0.7;
    }
  ];

  # preamp -> band1 -> ... -> band10, chained in declaration order.
  aryaChain = [
    {
      type = "builtin";
      name = "preamp";
      label = "linear";
      # `linear` exposes only Mult in PipeWire 1.4 — passing an Offset control
      # logs "control 'Offset' can not be set" and is silently dropped.
      control = {
        "Mult" = aryaPreampMult;
      };
    }
  ]
  ++ lib.imap1 (i: b: {
    type = "builtin";
    name = "eq_band_${toString i}";
    label = b.label;
    control = {
      "Freq" = b.freq;
      "Q" = b.q;
      "Gain" = b.gain;
    };
  }) aryaBands;

  aryaLinks = lib.zipListsWith (a: b: {
    output = "${a.name}:Out";
    input = "${b.name}:In";
  }) (lib.init aryaChain) (lib.tail aryaChain);
in
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
  #   Bluetooth headphones > Schiit Gunnr > FIIO SA1 (desk speakers) > Arya EQ > HDMI
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
  # selectable in pavucontrol or via SUPER+CTRL+S.
  services.pipewire.wireplumber.extraConfig."51-default-sink" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = schiitNode; } ];
        actions.update-props."priority.session" = 2000;
      }
      {
        matches = [ { "node.name" = fiioNode; } ];
        actions.update-props."priority.session" = 1500;
      }
      {
        matches = [ { "node.name" = hdmiNode; } ];
        actions.update-props."priority.session" = 100;
      }
    ];
    # Match the bluez *node*, not the device. `device.api = "bluez5"` matches
    # the device object, and priority.session is read off the node, so that
    # form silently does nothing: a connected WH-1000XM6 kept its stock 1010
    # and lost to the top-ranked wired output at 2000. The "~" prefix is
    # WirePlumber's regex match, covering every headset without hardcoding MACs
    # (bluez_output.80_99_E7_F8_6D_74.1 and friends).
    "monitor.bluez.rules" = [
      {
        matches = [ { "node.name" = "~bluez_output.*"; } ];
        actions.update-props."priority.session" = 3000;
      }
    ];
  };

  # Arya EQ: a filter-chain sink that applies the headphone correction and
  # feeds the Schiit Gunnr, which is what the Aryas are plugged into.
  #
  # This replaces EasyEffects, which was doing the same job badly: it was
  # configured with outputDevice = the FIIO and useDefaultOutputDevice = false,
  # so the *headphone* correction was being applied to the desk speakers. It
  # also inserted its virtual sink ahead of the hardware one and won the
  # default, which is how volume keys ended up moving a sink nothing played on.
  #
  # priority.session = 1200 sits below both the Schiit (2000) and the FIIO
  # (1500), so this sink can never take the default on its own — it is only
  # ever reached by picking it deliberately (SUPER+CTRL+S). That makes the old
  # failure mode structurally impossible rather than merely unlikely.
  services.pipewire.extraConfig.pipewire."99-arya-eq" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Arya EQ";
          "media.name" = "Arya EQ";
          "filter.graph" = {
            nodes = aryaChain;
            links = aryaLinks;
          };
          "audio.channels" = 2;
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = "effect_input.arya-eq";
            "node.description" = "Arya EQ → Schiit Gunnr";
            "media.class" = "Audio/Sink";
            "priority.session" = 1200;
          };
          "playback.props" = {
            "node.name" = "effect_output.arya-eq";
            "node.description" = "Arya EQ output";
            # Bind the corrected output to the Schiit specifically. Without
            # this the chain would follow the default sink and could end up
            # EQ-ing the speakers, which is the bug being fixed.
            "target.object" = schiitNode;
            # Don't hold the Schiit awake just because the chain is loaded.
            "node.passive" = true;
            "stream.dont-remix" = true;
          };
        };
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Speech bus — per-application capture routing for anarlog.
  #
  # The problem: anarlog records the mic on one channel and system audio on the
  # other, and system audio means the default sink's monitor, which is post-mix.
  # Music playing all day therefore lands in every meeting transcript.
  #
  # The obvious fix — make a virtual sink the default and route music around it
  # — is the wrong one, and would reintroduce the exact bug documented in the
  # 51-default-sink block above: volume keys target @DEFAULT_AUDIO_SINK@, so a
  # virtual default means the keys stop controlling whatever bypassed it. It
  # would also mean priority.session no longer selects what you hear.
  #
  # Instead the bus is deliberately NOT the default. Browsers are routed into
  # it, it loops back out to whatever the default sink happens to be, and
  # anarlog's capture stream is pinned to its monitor:
  #
  #   zen / chrome / helium ─→ [speech-bus] ─┬─ loopback ─→ default sink
  #                                          └─ monitor ──→ anarlog
  #   spotify / tidal / everything else ─────────────────→ default sink
  #
  # Consequences worth stating plainly, because they are the whole point:
  #   - The default sink is untouched. Volume keys behave exactly as before.
  #   - priority.session (bluez 3000 > Schiit 2000 > FIIO 1500) is untouched,
  #     and still selects the output. The loopback needs no target of its own:
  #     because the bus can never win the default, an untargeted playback
  #     stream follows the real default and thus follows Bluetooth on connect.
  #   - Music is inaudible to anarlog without ever being made inaudible to you.
  #
  # To add a source of speech (a Zoom or Slack desktop app, say), extend
  # speechAppMatches. To stop capturing one, remove it.
  services.pipewire.extraConfig.pipewire."98-speech-bus" = {
    "context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "support.null-audio-sink";
          "node.name" = speechBusNode;
          "node.description" = "Speech Bus (browsers → anarlog)";
          "media.class" = "Audio/Sink";
          "audio.position" = [
            "FL"
            "FR"
          ];
          "object.linger" = true;
          # 50 is far below every real output (HDMI, the lowest, is 100), so
          # this can never be auto-selected as the default sink. That is a
          # correctness requirement, not tidiness: if it ever became the
          # default, the loopback below would feed the bus back into itself.
          "priority.session" = 50;
          "priority.driver" = 50;
          # PipeWire's default, restated because the recording level depends on
          # it: the monitor tap is pre-volume, so changing the volume changes
          # what you hear without changing what anarlog records.
          "monitor.channel-volumes" = false;
        };
      }
    ];
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Speech Bus → default output";
          "capture.props" = {
            "node.name" = "speech-bus.loopback.capture";
            "target.object" = speechBusNode;
            "stream.capture.sink" = true;
            "stream.dont-remix" = true;
          };
          "playback.props" = {
            "node.name" = "speech-bus.loopback.playback";
            "media.class" = "Stream/Output/Audio";
            # Deliberately no target.object: this follows the default sink, so
            # browser audio lands wherever you are actually listening.
            # Passive so the bus doesn't hold the output awake (or keep a
            # Bluetooth headset from idling) when nothing is playing.
            "node.passive" = true;
            "stream.dont-remix" = true;
          };
        };
      }
    ];
  };

  # Browsers and anarlog both reach PipeWire through the PulseAudio
  # compatibility layer when they use libpulse, so the routing rules have to
  # live here as well as in client.conf.d below. Which path a given app takes
  # is its own business; covering both means we don't have to care.
  services.pipewire.extraConfig.pipewire-pulse."98-speech-bus-routing" = {
    "pulse.rules" = [
      {
        matches = speechAppMatches;
        actions.update-props."target.object" = speechBusNode;
      }
      anarlogCaptureRule
    ];
  };

  # The native-PipeWire path. anarlog's speaker capture is a pw_stream (the
  # PulseAudio path is only its fallback), so without this rule the pulse.rules
  # above would never fire for it.
  # (client-rt.conf was removed upstream; client.conf covers realtime streams
  # too, so this one file is the whole native-client story.)
  services.pipewire.extraConfig.client."98-speech-bus-capture" = {
    "stream.rules" = [ anarlogCaptureRule ];
  };

  environment.systemPackages = with pkgs; [
    pavucontrol
    pamixer
    playerctl
    qpwgraph # PipeWire patchbay
  ];
}
