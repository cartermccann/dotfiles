#!/usr/bin/env bash
# Leave the current meeting cleanly. In-flight Hermes tasks are not cancelled.
set -euo pipefail
UNIT=hermes-meet-runner

if ! systemctl --user is-active --quiet "$UNIT"; then
  echo "not_in_meeting"
  exit 0
fi
systemctl --user stop "$UNIT"
echo "left_meeting"
