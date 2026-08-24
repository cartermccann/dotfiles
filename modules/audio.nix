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
  granolaMeetingSink = "granola_mt";
  granolaMeetingOutput = "${granolaMeetingSink}.output";

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

  # Granola's Linux capture is pinned to this sink's monitor in
  # pkgs/granola/default.nix. Only verified meeting streams are routed here;
  # everything else (including Spotify and TIDAL) stays on the normal default
  # sink and is therefore structurally absent from Granola's system-audio
  # input. Google Meet exposes one playback stream per tab, with the page title
  # in media.name, so match that rather than all of Zen -- a blanket browser
  # rule would also capture YouTube, notifications, and every other tab.
  #
  # `stream.rules` cannot perform target selection in WirePlumber 0.5; it is
  # consumed by the stream-state script after link policy has inspected the
  # session item. Select the target in the linking hook instead, before
  # `linking/find-defined-target` and the default-target fallback run.
  services.pipewire.wireplumber.extraScripts."granola/route-meeting-audio.lua" = ''
    local lutils = require ("linking-utils")
    local cutils = require ("common-utils")
    local log = Log.open_topic ("s-granola-audio")

    local function is_google_meet (media_name)
      return media_name == "Meet"
          or media_name == "Google Meet"
          or string.sub (media_name, 1, 7) == "Meet - "
          or string.sub (media_name, 1, 14) == "Google Meet - "
    end

    SimpleEventHook {
      name = "linking/granola-meeting-target",
      before = "linking/find-defined-target",
      interests = {
        EventInterest {
          Constraint { "event.type", "=", "select-target" },
        },
      },
      execute = function (event)
        local _, om, si, si_props, _, target =
            lutils:unwrap_select_target_event (event)

        if target
            or si_props ["media.class"] ~= "Stream/Output/Audio"
            or si_props ["application.name"] ~= "Zen"
            or not is_google_meet (si_props ["media.name"] or "") then
          return
        end

        local target_direction = cutils.getTargetDirection (si_props)
        for candidate in om:iterate {
          type = "SiLinkable",
          Constraint { "node.name", "=", "${granolaMeetingSink}" },
          Constraint { "item.node.direction", "=", target_direction },
        } do
          if lutils.canLink (si_props, candidate) then
            log:info (si, "routing Google Meet to ${granolaMeetingSink}")
            event:set_data ("target", candidate)
            return
          end
        end

        log:warning (si, "${granolaMeetingSink} is unavailable; using normal link policy")
      end,
    }:register ()
  '';

  services.pipewire.wireplumber.extraConfig."52-granola-meeting-audio" = {
    "wireplumber.components" = [
      {
        name = "granola/route-meeting-audio.lua";
        type = "script/lua";
        provides = "custom.granola-meeting-audio";
      }
    ];
    "wireplumber.profiles".main."custom.granola-meeting-audio" = "required";

    # These rules only disable WirePlumber's remembered-target behavior. The
    # linking hook above owns the actual meeting target selection.
    "stream.rules" = [
      {
        matches = [
          {
            "media.class" = "Stream/Output/Audio";
            "application.name" = "Zen";
            "media.name" = "~^(Google )?Meet( - .*)?$";
          }
        ];
        actions.update-props = {
          # A previous pavucontrol move must not override the isolation rule.
          "state.restore-target" = false;
        };
      }
      {
        matches = [
          {
            "media.class" = "Stream/Output/Audio";
            "node.name" = granolaMeetingOutput;
          }
        ];
        actions.update-props."state.restore-target" = false;
      }
    ];
  };

  # Meeting-only bus. The capture side is an Audio/Sink, so PipeWire exports
  # its monitor as `granola_mt.monitor`; the playback side follows the normal
  # default sink, preserving the existing Arya/FIIO/Bluetooth output picker.
  # node.passive keeps the real output asleep when no meeting is using the bus.
  services.pipewire.extraConfig.pipewire."98-granola-meeting-audio" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Granola Meeting Audio";
          "audio.channels" = 2;
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = granolaMeetingSink;
            "node.description" = "Granola Meeting Audio";
            "media.class" = "Audio/Sink";
            "priority.session" = 50;
          };
          "playback.props" = {
            "node.name" = granolaMeetingOutput;
            "node.description" = "Granola Meeting Audio output";
            "node.passive" = true;
            "state.restore-target" = false;
          };
        };
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

  environment.systemPackages = with pkgs; [
    pavucontrol
    pamixer
    playerctl
    qpwgraph # PipeWire patchbay
  ];
}
