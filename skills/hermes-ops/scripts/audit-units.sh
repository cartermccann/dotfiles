#!/usr/bin/env bash
set -euo pipefail

if (($# == 0)); then
  set -- \
    ci-triage-loop.service \
    codex-self-improve-loop.service \
    docs-gardener-loop.service \
    kt-warmer-gsc-push.service \
    self-improve-loop.service
fi

state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}/unit-audit
details_dir=${state_dir%/unit-audit}/details
mkdir -p "$state_dir"
mkdir -p "$details_dir"
chmod 700 "$state_dir" "$details_dir"
umask 077
emit=${HERMES_EMIT_EVENT:-$(dirname -- "${BASH_SOURCE[0]}")/emit-event.sh}

for unit in "$@"; do
  if ! snapshot=$(systemctl --user show "$unit" \
    -p LoadState \
    -p ConditionResult \
    -p ConditionTimestamp \
    -p Result 2>/dev/null); then
    continue
  fi

  load_state=
  condition=
  condition_time=
  result=
  while IFS='=' read -r property value; do
    case "$property" in
      LoadState) load_state=$value ;;
      ConditionResult) condition=$value ;;
      ConditionTimestamp) condition_time=$value ;;
      Result) result=$value ;;
    esac
  done <<<"$snapshot"
  [[ $load_state == loaded ]] || continue

  signature="$condition|$condition_time|$result"
  key=$(printf '%s' "$unit" | sha256sum | cut -d ' ' -f 1)
  state_file="$state_dir/$key"
  previous=$(cat "$state_file" 2>/dev/null || true)
  transition_recorded=true

  # An empty ConditionTimestamp means systemd has not evaluated this unit's
  # conditions yet this boot — that is "never started", not "skipped". Every
  # unit looks like `no||success` after a reboot until its timer first fires,
  # so alerting on $condition alone reports a false skip for each pending unit
  # on every boot. A genuine skip always carries a populated timestamp.
  if [[ $signature != "$previous" && $condition == no && -n $condition_time ]]; then
    details=$(mktemp "$details_dir/unit-condition-${key:0:12}.XXXXXX.log")
    printf '%s\n' "$snapshot" >"$details"
    chmod 600 "$details"
    if ! "$emit" \
      --source systemd \
      --kind unit_condition_skipped \
      --severity warning \
      --subject "$unit skipped by a condition" \
      --unit "$unit" \
      --details "$details" \
      --notify; then
      transition_recorded=false
    fi
  fi

  if [[ $transition_recorded == true ]]; then
    state_tmp=$(mktemp "$state_dir/.state.XXXXXX")
    printf '%s\n' "$signature" >"$state_tmp"
    mv "$state_tmp" "$state_file"
  else
    printf 'warning: condition transition for %s will be retried after notification failure\n' "$unit" >&2
  fi
done
