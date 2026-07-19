#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: run-and-notify.sh --name NAME [--notify] -- COMMAND [ARG...]'
}

name=
notify=false
execute=false
unit=${HERMES_JOB_UNIT:-}

while (($#)); do
  case "$1" in
    --name) name=${2:?missing name}; shift 2 ;;
    --notify) notify=true; shift ;;
    --execute) execute=true; shift ;;
    --unit) unit=${2:?missing unit}; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n $name && $# -gt 0 ]] || { usage >&2; exit 2; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
emit=${HERMES_EMIT_EVENT:-$script_dir/emit-event.sh}

if [[ $execute == true ]]; then
  set +e
  "$@"
  rc=$?
  set -e

  if ((rc == 0)); then
    severity=notice
    kind=job_completed
    subject="$name completed"
  else
    severity=error
    kind=job_failed
    subject="$name failed with exit $rc"
  fi

  state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}
  details_dir="$state_dir/details"
  mkdir -p "$details_dir"
  chmod 700 "$state_dir" "$details_dir"
  umask 077
  safe_name=$(printf '%s' "$name" | tr -cs '[:alnum:]_.-' '-' | cut -c1-72)
  details=$(mktemp "$details_dir/job-${safe_name:-job}.XXXXXX.log")
  {
    printf 'name=%s\nunit=%s\nexit_code=%s\n' "$name" "$unit" "$rc"
    [[ -z $unit ]] || journalctl --user -u "$unit" -n 160 --no-pager || true
  } >"$details" 2>&1
  chmod 600 "$details"

  event_args=(
    --source systemd-run
    --kind "$kind"
    --severity "$severity"
    --subject "$subject"
    --unit "$unit"
    --details "$details"
  )
  [[ $notify == true ]] && event_args+=(--notify)
  if ! "$emit" "${event_args[@]}"; then
    printf 'warning: failed to record Hermes event for %s\n' "$name" >&2
  fi
  exit "$rc"
fi

slug=$(printf '%s' "$name" | tr -cs '[:alnum:]_.-' '-' | cut -c1-40)
slug=${slug#-}
slug=${slug%-}
[[ -n $slug ]] || slug=job
unit="hermes-job-${slug}-$(date +%s%N)-$$"
script_path=$(readlink -f "${BASH_SOURCE[0]}")

child_args=(--execute --name "$name" --unit "$unit")
[[ $notify == true ]] && child_args+=(--notify)
child_args+=(-- "$@")

environment_args=(--setenv=PATH="$PATH")
for variable in HERMES_BIN HERMES_EMIT_EVENT HERMES_OPS_STATE_DIR XDG_STATE_HOME; do
  if [[ -v $variable ]]; then
    environment_args+=(--setenv="$variable=${!variable}")
  fi
done

systemd-run --user \
  --unit="$unit" \
  --collect \
  --property=Type=exec \
  "${environment_args[@]}" \
  --working-directory="$PWD" \
  -- "$script_path" "${child_args[@]}"

printf 'unit=%s\n' "$unit"
printf 'status: systemctl --user status %s --no-pager\n' "$unit"
printf 'logs:   journalctl --user -u %s -n 160 --no-pager\n' "$unit"
