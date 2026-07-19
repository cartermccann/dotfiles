#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: emit-event.sh --source SOURCE --kind KIND --severity LEVEL --subject TEXT' \
    '                     [--unit UNIT] [--repo PATH] [--url URL] [--details PATH]' \
    '                     [--notify]'
}

source_name=
kind=
severity=
subject=
unit=
repo=
url=
details=
notify=false

while (($#)); do
  case "$1" in
    --source) source_name=${2:?missing source}; shift 2 ;;
    --kind) kind=${2:?missing kind}; shift 2 ;;
    --severity) severity=${2:?missing severity}; shift 2 ;;
    --subject) subject=${2:?missing subject}; shift 2 ;;
    --unit) unit=${2:?missing unit}; shift 2 ;;
    --repo) repo=${2:?missing repo}; shift 2 ;;
    --url) url=${2:?missing url}; shift 2 ;;
    --details) details=${2:?missing details}; shift 2 ;;
    --notify) notify=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z $source_name || -z $kind || -z $severity || -z $subject ]]; then
  usage >&2
  exit 2
fi

case "$severity" in
  debug|info|notice|warning|error|critical) ;;
  *) printf 'Invalid severity: %s\n' "$severity" >&2; exit 2 ;;
esac

state_dir=${HERMES_OPS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/hermes-ops}
event_dir="$state_dir/events"
mkdir -p "$event_dir"
chmod 700 "$state_dir" "$event_dir"
umask 077

timestamp=$(date -u +'%Y-%m-%dT%H:%M:%S.%NZ')
stamp=$(date -u +'%Y%m%dT%H%M%S.%N')
slug=$(printf '%s' "$subject" | tr -cs '[:alnum:]_.-' '-' | cut -c1-72)
slug=${slug#-}
slug=${slug%-}
[[ -n $slug ]] || slug=event
tmp_path=
cleanup() {
  [[ -z $tmp_path || ! -e $tmp_path ]] || rm -f -- "$tmp_path"
}
trap cleanup EXIT
tmp_path=$(mktemp "$event_dir/.event.XXXXXX")
unique=${tmp_path##*.event.}
event_path="$event_dir/${stamp}-${slug}-${unique}.json"

jq -n \
  --arg schema_version '1' \
  --arg timestamp "$timestamp" \
  --arg host "$(hostname)" \
  --arg source "$source_name" \
  --arg kind "$kind" \
  --arg severity "$severity" \
  --arg subject "$subject" \
  --arg unit "$unit" \
  --arg repo "$repo" \
  --arg url "$url" \
  --arg details "$details" \
  '{
    schema_version: ($schema_version | tonumber),
    timestamp: $timestamp,
    host: $host,
    source: $source,
    kind: $kind,
    severity: $severity,
    subject: $subject,
    unit: (if $unit == "" then null else $unit end),
    repo: (if $repo == "" then null else $repo end),
    url: (if $url == "" then null else $url end),
    details: (if $details == "" then null else $details end)
  }' >"$tmp_path"

chmod 600 "$tmp_path"
mv "$tmp_path" "$event_path"
tmp_path=

printf '%s\n' "$event_path"

if [[ $notify == true ]]; then
  hermes_bin=${HERMES_BIN:-hermes}
  body="$source_name/$kind"
  [[ -n $unit ]] && body+=" | unit: $unit"
  [[ -n $repo ]] && body+=" | repo: $repo"
  [[ -n $url ]] && body+=" | url: $url"
  [[ -n $details ]] && body+=" | details: $details"
  "$hermes_bin" send -t telegram -s "Hermes $severity: $subject" "$body"
fi
