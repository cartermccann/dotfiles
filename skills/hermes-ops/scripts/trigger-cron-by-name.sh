#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: trigger-cron-by-name.sh [--accept-hooks] [--retry-busy SECONDS] JOB_NAME\n'
}

accept_hooks=false
retry_busy=0
while (($#)); do
  case "$1" in
    --accept-hooks) accept_hooks=true; shift ;;
    --retry-busy) retry_busy=${2:?missing seconds}; shift 2 ;;
    --) shift; break ;;
    -*) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

[[ $# == 1 ]] || { usage >&2; exit 2; }
[[ $retry_busy =~ ^[0-9]+$ ]] || { printf 'Retry delay must be a non-negative integer\n' >&2; exit 2; }
target=$1
hermes_bin=${HERMES_BIN:-hermes}
listing=$("$hermes_bin" cron list --all)

mapfile -t ids < <(
  awk -v target="$target" '
    /^[[:space:]]*[^[:space:]]+[[:space:]]+\[/ {
      current = $1
      if (current !~ /^[[:alnum:]][[:alnum:]_.:-]*$/) current = ""
      next
    }
    /^[[:space:]]*Name:[[:space:]]*/ {
      name = $0
      sub(/^[[:space:]]*Name:[[:space:]]*/, "", name)
      if (name == target && current != "") print current
      current = ""
    }
  ' <<<"$listing"
)

if ((${#ids[@]} == 0)); then
  printf 'No Hermes cron job named %q\n' "$target" >&2
  exit 1
fi
if ((${#ids[@]} > 1)); then
  printf 'Hermes cron name is ambiguous (%d matches): %s\n' "${#ids[@]}" "$target" >&2
  exit 1
fi

args=(cron run)
[[ $accept_hooks == true ]] && args+=(--accept-hooks)
args+=("${ids[0]}")

attempt=1
max_attempts=${HERMES_CRON_BUSY_RETRIES:-12}
[[ $max_attempts =~ ^[1-9][0-9]*$ ]] || { printf 'HERMES_CRON_BUSY_RETRIES must be a positive integer\n' >&2; exit 2; }

while :; do
  set +e
  result=$("$hermes_bin" "${args[@]}" 2>&1)
  rc=$?
  set -e
  printf '%s\n' "$result"
  ((rc == 0)) || exit "$rc"

  case "$result" in
    *"Ran now: failed."*)
      printf 'failed name=%s id=%s\n' "$target" "${ids[0]}" >&2
      exit 1
      ;;
    *"Ran now: succeeded."*)
      printf 'completed name=%s id=%s\n' "$target" "${ids[0]}"
      exit 0
      ;;
    *"Already being fired by the scheduler"*)
      if ((retry_busy > 0 && attempt < max_attempts)); then
        printf 'busy name=%s id=%s; retrying in %ss (%d/%d)\n' \
          "$target" "${ids[0]}" "$retry_busy" "$attempt" "$max_attempts"
        sleep "$retry_busy"
        attempt=$((attempt + 1))
        continue
      fi
      printf 'already-running name=%s id=%s\n' "$target" "${ids[0]}" >&2
      exit 75
      ;;
    *)
      printf 'queued name=%s id=%s\n' "$target" "${ids[0]}"
      exit 0
      ;;
  esac
done
