#!/usr/bin/env bash
# Join a Google Meet as the Hermes voice bot. Prints stable codes only.
# Usage: meet-join.sh <meet-url> --consented
set -euo pipefail

REPO=/home/cjm/projects/Personal/hermes-integrations
ENVFILE=/home/cjm/.config/credentials/hermes-meet.env
UNIT=hermes-meet-runner

url="${1:-}"
consent="${2:-}"

if [[ "$consent" != "--consented" ]]; then
  echo "consent_not_attested"
  exit 2
fi
if [[ ! "$url" =~ ^https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}$ ]]; then
  echo "invalid_meet_url"
  exit 2
fi
if [[ ! -f "$ENVFILE" ]]; then
  echo "missing_environment_file"
  exit 2
fi
if systemctl --user is-active --quiet "$UNIT"; then
  echo "already_in_meeting"
  exit 3
fi

# Lane services are idempotent to start; the runner needs all three.
# Local voice is RESTARTED, not started: interim mitigation for the
# reconnect race (Story 2.10) — a prior session's teardown can leak frames
# into the next connection. Remove the restart once 2.10 lands.
systemctl --user start hermes-attendee hermes-agent-backend
systemctl --user restart hermes-local-voice

set -a; . "$ENVFILE"; set +a
cd "$REPO"

# Transient --user units don't inherit the login PATH, so resolve node absolutely.
NODE="$(command -v node)"
if [[ -z "$NODE" ]]; then
  echo "node_not_found"
  exit 4
fi

# Phase 2: when the Luna upstream points at the local Hermes-voice adapter, bring
# it up (Nastija IS the real Hermes agent). Restarted per join so each meeting
# gets a fresh Hermes session, mirroring the local-voice restart above.
if printf '%s' "${LUNA_UPSTREAM_URL:-}" | grep -q "127.0.0.1:${HERMES_VOICE_UPSTREAM_PORT:-8785}"; then
  systemctl --user reset-failed hermes-voice-upstream 2>/dev/null || true
  systemctl --user stop hermes-voice-upstream 2>/dev/null || true
  systemd-run --user --unit=hermes-voice-upstream --collect \
    --property=EnvironmentFile="$ENVFILE" \
    --working-directory="$REPO" \
    "$NODE" scripts/hermes-voice-upstream.mjs >/dev/null
  adapter_ready=""
  for _ in $(seq 1 20); do
    if curl -sf -m 2 "http://127.0.0.1:${HERMES_VOICE_UPSTREAM_PORT:-8785}/healthz" >/dev/null 2>&1; then
      adapter_ready=yes
      break
    fi
    sleep 1
  done
  if [[ -z "$adapter_ready" ]]; then
    echo "hermes_voice_adapter_not_ready"
    exit 4
  fi
fi

# Wait for the voice sidecar (cold model load can take ~1 min).
ready=""
for _ in $(seq 1 24); do
  if curl -sf -m 3 "${HERMES_LOCAL_VOICE_HEALTH_URL:?}" >/dev/null 2>&1; then
    ready=yes
    break
  fi
  sleep 5
done
if [[ -z "$ready" ]]; then
  echo "local_voice_not_ready"
  exit 4
fi

# Full lane readiness; on failure surface the missing capability names.
if ! readiness_out=$(node scripts/task-lane-readiness.mjs 2>&1); then
  echo "readiness_failed: $(printf '%s' "$readiness_out" | tail -2)"
  exit 4
fi

systemd-run --user --unit="$UNIT" --collect \
  --working-directory="$REPO" \
  --property=EnvironmentFile="$ENVFILE" \
  "$NODE" scripts/run-meet-voice-poc.mjs --enable \
  --consent-all-participants --consent-local-voice \
  --meeting-url "$url" >/dev/null

sleep 8
if systemctl --user is-active --quiet "$UNIT"; then
  echo "joined_pending_admission"
else
  echo "runner_failed_at_start"
  journalctl --user -u "$UNIT" --since '-1 min' --no-pager 2>/dev/null | tail -5
  exit 5
fi
