{
  config,
  pkgs,
  ...
}:

# Hermes Meet task lane (hermes-integrations Story 2.7) — declarative services
# for the owner-only Google Meet voice + task delegation stack on kronos.
#
# Service ownership follows ADR-005 in the hermes-integrations architecture:
#   - hermes-agent-backend  — real Hermes JSON-RPC gateway on loopback :9119
#   - hermes-local-voice    — speech sidecar (Whisper/Kokoro), kept warm
#   - hermes-attendee       — pinned self-hosted Attendee Compose stack (v1.58.1)
# The Meet control runner (`npm run meet:poc`) stays foreground/manual through
# qualification and is deliberately NOT a service yet.
#
# All three units are start-on-demand (no WantedBy): Story 2.7 qualification is
# operator-controlled, so nothing auto-starts at login. Start order for a
# session:
#   systemctl --user start hermes-attendee hermes-agent-backend hermes-local-voice
# After qualification passes, add Install sections to auto-start if desired.
#
# Secrets and Carter-supplied durations live OUTSIDE this repo in
#   ~/.config/credentials/hermes-meet.env   (chmod 600)
# This module references only the path; the hermes-integrations repo defines
# the variable names (.env.example). The three lifecycle durations
# (HERMES_MEET_TASK_EXECUTION_TIMEOUT_MS, HERMES_MEET_QUEUED_TASK_EXPIRY_MS,
# HERMES_MEET_DETACHED_SESSION_CLEANUP_TTL_MS) have no defaults by design and
# must be set there explicitly before live qualification.
let
  homeDir = config.home.homeDirectory;
  repo = "${homeDir}/projects/Personal/hermes-integrations";
  meetEnv = "${homeDir}/.config/credentials/hermes-meet.env";
  hermesVenvBin = "${homeDir}/.hermes/hermes-agent/venv/bin";
  # Real Hermes spawns terminal/file/browser tools while serving tasks, so the
  # backend needs the same NixOS-aware PATH the hermes-gateway override uses.
  hermesToolPath = "${hermesVenvBin}:${homeDir}/.hermes/hermes-agent/node_modules/.bin:${homeDir}/.local/state/nix/profiles/home-manager/home-path/bin:${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin";
in
{
  systemd.user.services.hermes-agent-backend = {
    Unit = {
      Description = "Real Hermes agent backend (loopback JSON-RPC gateway for the Meet task lane)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Skip cleanly when the operator env file or the self-managed Hermes
      # install is absent — never start a task gateway with missing identity.
      ConditionPathExists = [
        meetEnv
        "${hermesVenvBin}/hermes"
      ];
    };
    Service = {
      Type = "simple";
      EnvironmentFile = meetEnv;
      Environment = [
        "PATH=${hermesToolPath}"
        "HERMES_HOME=${homeDir}/.hermes"
      ];
      ExecStart = "${hermesVenvBin}/hermes serve --host 127.0.0.1 --port 9119 --skip-build";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.user.services.hermes-local-voice = {
    Unit = {
      Description = "Hermes local voice sidecar (Whisper STT + Kokoro TTS, models kept warm)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = [
        meetEnv
        "${repo}/services/local-voice/pyproject.toml"
      ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = repo;
      EnvironmentFile = meetEnv;
      # The sidecar's native deps (ctranslate2, espeak-ng, libsndfile) come from
      # the repo's pinned dev shell; running through it keeps the service
      # byte-identical to how `npm run voice:serve` behaves in qualification.
      ExecStart = "/run/current-system/sw/bin/nix develop ${repo} --command uv run --frozen --project ${repo}/services/local-voice hermes-local-voice serve";
      Restart = "on-failure";
      RestartSec = 5;
      # First start downloads/loads speech models; don't let a slow warmup
      # count as a hang.
      TimeoutStartSec = 600;
    };
  };

  systemd.user.services.hermes-attendee = {
    Unit = {
      Description = "Self-hosted Attendee meeting transport (pinned v1.58.1 Compose stack)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = [
        "${repo}/infra/attendee/bin/attendee"
        "${homeDir}/projects/Personal/attendee/.git"
      ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = repo;
      Environment = [
        "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
        "ATTENDEE_SOURCE_DIR=${homeDir}/projects/Personal/attendee"
      ];
      # `up` verifies the pinned commit + patch before touching Compose and is
      # idempotent; `down` stops the stack without destroying volumes.
      ExecStart = "${repo}/infra/attendee/bin/attendee up";
      ExecStop = "${repo}/infra/attendee/bin/attendee down";
      TimeoutStartSec = 900;
    };
  };
}
