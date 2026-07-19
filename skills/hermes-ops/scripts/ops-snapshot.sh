#!/usr/bin/env bash
set -euo pipefail

lines_to_json() {
  jq -Rsc 'split("\n") | map(select(length > 0))'
}

command_lines() {
  "$@" 2>/dev/null || true
}

user_failed=$(command_lines systemctl --user --failed --no-legend --plain | awk '{print $1}' | lines_to_json)
system_failed=$(command_lines systemctl --failed --no-legend --plain | awk '{print $1}' | lines_to_json)
user_timers=$(command_lines systemctl --user list-timers --all --no-legend --no-pager | lines_to_json)

gateway_state=$(systemctl --user is-active hermes-gateway.service 2>/dev/null || true)
gateway_restarts=$(systemctl --user show hermes-gateway.service -p NRestarts --value 2>/dev/null || printf '0')
[[ $gateway_restarts =~ ^[0-9]+$ ]] || gateway_restarts=0

read -r mem_total mem_available < <(free -b | awk '/^Mem:/ {print $2, $7}')
read -r disk_size disk_used disk_available disk_percent < <(df -B1 --output=size,used,avail,pcent / | tail -n 1)

if command -v docker >/dev/null 2>&1; then
  if container_lines=$(docker ps --format '{{json .}}' 2>/dev/null); then
    containers=$(jq -s 'map({
      id: .ID,
      name: .Names,
      image: .Image,
      state: .State,
      status: .Status,
      ports: .Ports
    })' <<<"$container_lines" 2>/dev/null || printf '[]')
  else
    containers='[]'
  fi
else
  containers='[]'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_lines=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || true)
  gpu=$(lines_to_json <<<"$gpu_lines")
else
  gpu='[]'
fi

repos='[]'
declare -A seen=()
for repo in "$HOME/dotfiles" "$@"; do
  [[ -n $repo && -d $repo/.git && -z ${seen[$repo]+x} ]] || continue
  seen[$repo]=1
  branch=$(git -C "$repo" branch --show-current 2>/dev/null || true)
  head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)
  dirty_status=$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null || true)
  dirty_count=$(awk 'NF { count++ } END { print count + 0 }' <<<"$dirty_status")
  repos=$(jq \
    --arg path "$repo" \
    --arg branch "$branch" \
    --arg head "$head" \
    --argjson dirty_count "$dirty_count" \
    '. + [{path: $path, branch: $branch, head: $head, dirty_count: $dirty_count}]' \
    <<<"$repos")
done

jq -n \
  --arg timestamp "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg host "$(hostname)" \
  --arg uptime "$(uptime -p 2>/dev/null || true)" \
  --arg gateway_state "$gateway_state" \
  --argjson gateway_restarts "$gateway_restarts" \
  --argjson mem_total "$mem_total" \
  --argjson mem_available "$mem_available" \
  --argjson disk_size "$disk_size" \
  --argjson disk_used "$disk_used" \
  --argjson disk_available "$disk_available" \
  --arg disk_percent "$disk_percent" \
  --argjson user_failed "$user_failed" \
  --argjson system_failed "$system_failed" \
  --argjson user_timers "$user_timers" \
  --argjson containers "$containers" \
  --argjson gpu "$gpu" \
  --argjson repos "$repos" \
  '{
    timestamp: $timestamp,
    host: $host,
    uptime: $uptime,
    memory_bytes: {total: $mem_total, available: $mem_available},
    root_disk_bytes: {size: $disk_size, used: $disk_used, available: $disk_available, percent: $disk_percent},
    hermes_gateway: {state: $gateway_state, restarts: $gateway_restarts},
    failed_units: {user: $user_failed, system: $system_failed},
    user_timers: $user_timers,
    containers: $containers,
    gpu: $gpu,
    repositories: $repos
  }'
