#!/usr/bin/env bash
set -euo pipefail

docker_bin=${DOCKER_BIN:-docker}
emit=${HERMES_EMIT_EVENT:-$(dirname -- "${BASH_SOURCE[0]}")/emit-event.sh}
declare -A last_oom=()
declare -A last_expected_stop=()
state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}
details_dir="$state_dir/details"
mkdir -p "$details_dir"
chmod 700 "$state_dir" "$details_dir"
umask 077

"$docker_bin" events \
  --filter type=container \
  --filter event=die \
  --filter event=kill \
  --filter event=oom \
  --filter event=start \
  --filter event=health_status \
  --format '{{json .}}' |
while IFS= read -r event; do
  jq -e 'type == "object"' <<<"$event" >/dev/null 2>&1 || continue
  exit_code=
  action=$(jq -r '.Action // "unknown"' <<<"$event")
  name=$(jq -r '.Actor.Attributes.name // .id // "container"' <<<"$event")
  id=$(jq -r '.id // .Actor.ID // ""' <<<"$event")
  event_key=${id:-$name}
  now=$(date +%s)

  case "$action" in
    kill)
      last_expected_stop["$event_key"]=$now
      continue
      ;;
    start)
      unset 'last_expected_stop[$event_key]' 'last_oom[$event_key]'
      continue
      ;;
    oom)
      severity=critical
      last_oom["$event_key"]=$now
      ;;
    *unhealthy*) severity=critical ;;
    *healthy*) continue ;;
    die)
      exit_code=$(jq -r '.Actor.Attributes.exitCode // ""' <<<"$event")
      [[ $exit_code == 0 ]] && continue
      if [[ -n ${last_expected_stop[$event_key]+x} ]] && ((now - last_expected_stop[$event_key] <= 30)); then
        unset 'last_expected_stop[$event_key]'
        continue
      fi
      if [[ $exit_code == 137 && -n ${last_oom[$event_key]+x} ]] && ((now - last_oom[$event_key] <= 30)); then
        unset 'last_oom[$event_key]'
        continue
      fi
      severity=error
      ;;
    *) severity=warning ;;
  esac

  details=$(mktemp "$details_dir/docker-${event_key//[^[:alnum:]_.-]/-}.XXXXXX.log")
  {
    printf 'container=%s\nid=%s\naction=%s\n' "$name" "$id" "$action"
    [[ ${exit_code:-} == '' ]] || printf 'exit_code=%s\n' "$exit_code"
    "$docker_bin" inspect --format '{{json .State}}' "$id" 2>/dev/null || true
  } >"$details"
  chmod 600 "$details"

  if ! "$emit" \
    --source docker \
    --kind "container_${action//[^[:alnum:]_]/_}" \
    --severity "$severity" \
    --subject "$name: $action" \
    --details "$details" \
    --notify; then
    printf 'warning: failed to record or deliver Docker event for %s\n' "$name" >&2
  fi
done
