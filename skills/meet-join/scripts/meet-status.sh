#!/usr/bin/env bash
# Report the Meet runner's state. Content-free output only.
set -euo pipefail
UNIT=hermes-meet-runner

state=$(systemctl --user is-active "$UNIT" 2>/dev/null || true)
echo "runner: ${state:-inactive}"
if [[ "$state" == "active" ]]; then
  journalctl --user -u "$UNIT" --no-pager 2>/dev/null | tail -8
fi
for svc in hermes-attendee hermes-agent-backend hermes-local-voice; do
  echo "$svc: $(systemctl --user is-active "$svc" 2>/dev/null || echo inactive)"
done
