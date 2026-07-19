#!/usr/bin/env bash
set -euo pipefail

state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}
mkdir -p "$state_dir"
chmod 700 "$state_dir"
state_file="$state_dir/gateway-health.state"
details_dir="$state_dir/details"
mkdir -p "$details_dir"
chmod 700 "$details_dir"
umask 077

capture_details() {
  local details
  details=$(mktemp "$details_dir/hermes-gateway.XXXXXX.log")
  {
    systemctl --user status hermes-gateway.service --no-pager || true
    journalctl --user -u hermes-gateway.service -n 200 --no-pager || true
  } >"$details" 2>&1
  chmod 600 "$details"
  printf '%s\n' "$details"
}

active=$(systemctl --user is-active hermes-gateway.service 2>/dev/null || true)
[[ -n $active ]] || active=unknown
restarts=$(systemctl --user show hermes-gateway.service -p NRestarts --value 2>/dev/null || printf '0')
[[ $restarts =~ ^[0-9]+$ ]] || restarts=0
current="$active $restarts"

if [[ ! -f $state_file ]]; then
  printf '%s\n' "$current" >"$state_file"
  exit 0
fi

read -r previous_state previous_restarts <"$state_file" || true
[[ ${previous_restarts:-} =~ ^[0-9]+$ ]] || previous_restarts=0
emit=${HERMES_EMIT_EVENT:-$(dirname -- "${BASH_SOURCE[0]}")/emit-event.sh}
transition_recorded=true

if [[ $active != active && ${previous_state:-unknown} == active ]]; then
  details=$(capture_details)
  if ! "$emit" \
    --source hermes-gateway \
    --kind gateway_unhealthy \
    --severity critical \
    --subject "Hermes gateway is $active" \
    --unit hermes-gateway.service \
    --details "$details" \
    --notify; then
    transition_recorded=false
  fi
elif [[ $active == active && ${previous_state:-unknown} != active ]]; then
  if ! "$emit" \
    --source hermes-gateway \
    --kind gateway_recovered \
    --severity notice \
    --subject "Hermes gateway recovered" \
    --unit hermes-gateway.service \
    --notify; then
    transition_recorded=false
  fi
elif ((restarts > previous_restarts)); then
  details=$(capture_details)
  if ! "$emit" \
    --source hermes-gateway \
    --kind gateway_restarted \
    --severity warning \
    --subject "Hermes gateway restarted ($previous_restarts -> $restarts)" \
    --unit hermes-gateway.service \
    --details "$details" \
    --notify; then
    transition_recorded=false
  fi
fi

if [[ $transition_recorded == true ]]; then
  printf '%s\n' "$current" >"$state_file"
else
  printf 'warning: Hermes gateway transition was recorded locally but notification failed; retry retained\n' >&2
fi
