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
  node scripts/run-meet-voice-poc.mjs --enable \
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
