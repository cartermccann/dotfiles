#!/usr/bin/env bash
set -euo pipefail

unit=${1:?unit name required}
state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}
details_dir="$state_dir/details"
mkdir -p "$details_dir"
chmod 700 "$state_dir" "$details_dir"
umask 077

safe_unit=$(printf '%s' "$unit" | tr -cs '[:alnum:]_.@-' '-' | cut -c1-96)
details=$(mktemp "$details_dir/$(date -u +'%Y%m%dT%H%M%S.%N')-${safe_unit}.XXXXXX.log")
journalctl --user -u "$unit" -n 200 --no-pager >"$details" 2>&1 || true
chmod 600 "$details"

emit=${HERMES_EMIT_EVENT:-$(dirname -- "${BASH_SOURCE[0]}")/emit-event.sh}
"$emit" \
  --source systemd \
  --kind unit_failed \
  --severity error \
  --subject "$unit failed" \
  --unit "$unit" \
  --details "$details" \
  --notify || true

if command -v notify-send >/dev/null 2>&1; then
  notify-send --urgency=critical "Hermes: $unit failed" "Details: $details" || true
fi
