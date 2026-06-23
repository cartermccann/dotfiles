#!/usr/bin/env bash
# Animated cascade-reveal wrapper for fastfetch (neon gradient config).
# Captures fastfetch output (forcing TTY colors + logo cursor control) and
# replays it line-by-line for a snappy top-to-bottom reveal.
set -u

# Respect non-interactive / dumb terminals and a NO_ANIM escape hatch.
if [[ -n "${NO_ANIM:-}" || ! -t 1 || "${TERM:-dumb}" == "dumb" ]]; then
  exec fastfetch "$@"
fi

# Per-line delay (seconds). Override with FF_DELAY=0 to disable, FF_DELAY=0.02 for drama.
delay="${FF_DELAY:-0.007}"

# Capture with colors + cursor positioning preserved.
mapfile -t lines < <(fastfetch --pipe false "$@")

printf '\e[?25l'  # hide cursor during reveal
for line in "${lines[@]}"; do
  printf '%s\n' "$line"
  [[ "$delay" != "0" ]] && sleep "$delay"
done
printf '\e[?25h'  # show cursor
