{
  config,
  lib,
  pkgs,
  qmd,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  stateDir = "${homeDir}/.local/state/hermes-ops";
  hermesBin = "${homeDir}/.local/bin/hermes";
  qmdPackage = qmd.packages.${pkgs.stdenv.hostPlatform.system}.default;

  scriptBody = path: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);
  mkScript =
    {
      name,
      path,
      runtimeInputs ? [ ],
      prefix ? "",
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = prefix + scriptBody path;
    };

  emitEvent = mkScript {
    name = "hermes-emit-event";
    path = ../skills/hermes-ops/scripts/emit-event.sh;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.inetutils
      pkgs.jq
    ];
  };

  scriptPrefix = ''
    export HERMES_EMIT_EVENT=${emitEvent}/bin/hermes-emit-event
  '';

  opsSnapshot = mkScript {
    name = "hermes-ops-snapshot";
    path = ../skills/hermes-ops/scripts/ops-snapshot.sh;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker-client
      pkgs.gawk
      pkgs.git
      pkgs.inetutils
      pkgs.jq
      pkgs.procps
      pkgs.systemd
    ];
  };

  runAndNotify = mkScript {
    name = "hermes-run-and-notify";
    path = ../skills/hermes-ops/scripts/run-and-notify.sh;
    runtimeInputs = [
      emitEvent
      pkgs.coreutils
      pkgs.systemd
    ];
    prefix = scriptPrefix;
  };

  triggerCron = mkScript {
    name = "hermes-trigger-cron";
    path = ../skills/hermes-ops/scripts/trigger-cron-by-name.sh;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
  };

  unitFailed = mkScript {
    name = "hermes-unit-failed";
    path = ../skills/hermes-ops/scripts/unit-failed.sh;
    runtimeInputs = [
      emitEvent
      pkgs.coreutils
      pkgs.libnotify
      pkgs.systemd
    ];
    prefix = scriptPrefix;
  };

  gatewayHealth = mkScript {
    name = "hermes-gateway-health";
    path = ../skills/hermes-ops/scripts/gateway-health.sh;
    runtimeInputs = [
      emitEvent
      pkgs.coreutils
      pkgs.systemd
    ];
    prefix = scriptPrefix;
  };

  auditUnits = mkScript {
    name = "hermes-audit-units";
    path = ../skills/hermes-ops/scripts/audit-units.sh;
    runtimeInputs = [
      emitEvent
      pkgs.coreutils
      pkgs.systemd
    ];
    prefix = scriptPrefix;
  };

  dockerEvents = mkScript {
    name = "hermes-docker-events";
    path = ../skills/hermes-ops/scripts/docker-events.sh;
    runtimeInputs = [
      emitEvent
      pkgs.coreutils
      pkgs.docker-client
      pkgs.jq
    ];
    prefix = scriptPrefix;
  };

  eventEnvironment = [
    "HERMES_BIN=${hermesBin}"
    "HERMES_OPS_STATE_DIR=${stateDir}"
  ];
  failureTarget = [ "hermes-unit-failed@%n.service" ];
in
lib.mkIf (config.home.username == "cjm") {
  home.packages = [
    emitEvent
    opsSnapshot
    runAndNotify
    triggerCron
  ];

  systemd.user.services = {
    "hermes-unit-failed@" = {
      Unit.Description = "Report failed user unit %i through Hermes";
      Service = {
        Type = "oneshot";
        ExecStart = "${unitFailed}/bin/hermes-unit-failed %i";
        Environment = eventEnvironment;
      };
    };

    ci-triage-loop.Unit.OnFailure = failureTarget;
    codex-self-improve-loop.Unit.OnFailure = failureTarget;
    docs-gardener-loop.Unit.OnFailure = failureTarget;
    kt-warmer-gsc-push.Unit.OnFailure = failureTarget;
    self-improve-loop.Unit.OnFailure = failureTarget;

    hermes-gateway-health = {
      Unit.Description = "Detect Hermes gateway outages and restart transitions";
      Service = {
        Type = "oneshot";
        ExecStart = "${gatewayHealth}/bin/hermes-gateway-health";
        Environment = eventEnvironment;
      };
    };

    hermes-unit-audit = {
      Unit.Description = "Detect systemd condition-skips that do not count as failures";
      Service = {
        Type = "oneshot";
        ExecStart = "${auditUnits}/bin/hermes-audit-units";
        Environment = eventEnvironment;
      };
    };

    hermes-docker-events = {
      Unit = {
        Description = "Route Docker container failures into Hermes events";
        After = [ "default.target" ];
        OnFailure = failureTarget;
        StartLimitIntervalSec = 300;
        StartLimitBurst = 6;
      };
      Service = {
        Type = "simple";
        ExecStart = "${dockerEvents}/bin/hermes-docker-events";
        Environment = eventEnvironment;
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    qmd-index-update = {
      Unit = {
        Description = "Refresh Carter's QMD document index";
        OnFailure = failureTarget;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${qmdPackage}/bin/qmd update";
        TimeoutStartSec = 1800;
      };
    };

    qmd-index-embed = {
      Unit = {
        Description = "Refresh QMD embeddings and reranking index";
        OnFailure = failureTarget;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${qmdPackage}/bin/qmd embed";
        TimeoutStartSec = 14400;
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    hermes-document-inbox = {
      Unit = {
        Description = "Queue Hermes document ingestion after Downloads changes";
        OnFailure = failureTarget;
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 15";
        ExecStart = "${triggerCron}/bin/hermes-trigger-cron --retry-busy 60 weekday-document-inbox-triage-and-safe-import";
        Environment = eventEnvironment;
        TimeoutStartSec = 1000;
      };
    };
  };

  systemd.user.timers = {
    hermes-gateway-health = {
      Unit.Description = "Periodically verify the Hermes gateway";
      Timer = {
        OnBootSec = "3m";
        OnUnitActiveSec = "5m";
        Unit = "hermes-gateway-health.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    hermes-unit-audit = {
      Unit.Description = "Audit important user units for condition-skips";
      Timer = {
        OnBootSec = "7m";
        OnUnitActiveSec = "15m";
        Unit = "hermes-unit-audit.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    qmd-index-update = {
      Unit.Description = "Refresh QMD lexical index every 30 minutes";
      Timer = {
        OnCalendar = "*-*-* *:00/30:00";
        Persistent = true;
        Unit = "qmd-index-update.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    qmd-index-embed = {
      Unit.Description = "Refresh QMD embeddings weekly";
      Timer = {
        OnCalendar = "Sun *-*-* 03:15:00";
        Persistent = true;
        RandomizedDelaySec = "20m";
        Unit = "qmd-index-embed.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.paths.hermes-document-inbox = {
    Unit.Description = "Watch Downloads for documents Hermes can ingest";
    Path = {
      PathChanged = "${homeDir}/Downloads";
      Unit = "hermes-document-inbox.service";
    };
    Install.WantedBy = [ "default.target" ];
  };

  xdg.configFile."systemd/user/cbbot-advance.service.d/20-hermes-events.conf" = {
    force = true;
    text = ''
      [Unit]
      OnFailure=hermes-unit-failed@%n.service
    '';
  };
}
