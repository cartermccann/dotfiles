# MCP reaper: clean up leaked MCP servers and headless Playwright browsers.
#
# Two independent phases with very different confidence levels:
#
#   Phase A (playwright, ARMED): kills browsers that are provably dead or
#   provably pathological. An orphaned browser whose owning playwright-mcp
#   server is gone can never be used again. A headless SwiftShader browser
#   burning hundreds of percent CPU is rendering WebGL in software with no
#   vsync ceiling, which is never legitimate for automation.
#
#   Phase B (idle MCP servers, DRY-RUN by default): codex app-server does not
#   reap MCP servers when a conversation ends, so they accumulate indefinitely
#   (observed: 333 children / 20GB over ~27h). There is no clean "is this
#   live?" signal — every leaked server still holds a live stdio pipe to
#   app-server, so pipe state proves nothing. What does separate them is
#   traffic: a live server has a client that at minimum pings it, a leaked one
#   can never receive another byte. Phase B tracks rchar per process across
#   runs and only acts after MANY consecutive runs of exactly zero growth.
#   Arm it with MCP_REAPER_ARM_IDLE=1 once you have reviewed a few dry runs.
#
# Everything is logged to the journal: journalctl --user -u mcp-reaper

set -o errexit
set -o nounset
set -o pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mcp-reaper"
STATE_FILE="$STATE_DIR/idle-state.tsv"
PW_CACHE="$HOME/.cache/ms-playwright-mcp"

# Phase A tuning
SPIN_PCT="${MCP_REAPER_SPIN_PCT:-200}"      # sustained CPU% that marks a wedged browser
# 5s is ample: a wedged SwiftShader browser reads 800-1200%, nowhere near the
# threshold's noise floor. Kept short because this sample is the only thing
# that makes a run expensive, and the run cadence is what bounds how long a
# spin burns (observed: wedges ~90s after launch, so the timer interval is
# very close to the worst-case burn time).
SPIN_SAMPLE_SECS="${MCP_REAPER_SPIN_SECS:-5}"
PROFILE_GC_DAYS="${MCP_REAPER_PROFILE_GC_DAYS:-3}"

# Phase B tuning
ARM_IDLE="${MCP_REAPER_ARM_IDLE:-0}"        # 0 = dry run, log only
IDLE_MIN_AGE_SECS="${MCP_REAPER_IDLE_MIN_AGE:-7200}"    # never touch anything younger than 2h
IDLE_ZERO_SECS="${MCP_REAPER_IDLE_ZERO_SECS:-21600}"    # 6h of exactly zero rchar growth
MAX_KILLS="${MCP_REAPER_MAX_KILLS:-40}"     # blast-radius cap per run

DRY="${MCP_REAPER_DRY_RUN:-0}"              # 1 = log everything, kill nothing at all

mkdir -p "$STATE_DIR"

log() { printf '%s\n' "$*"; }

now_epoch() { date +%s; }

# Process identity that survives PID reuse: pid + starttime (stat field 22).
proc_key() {
  local pid="$1" st
  st="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)" || return 1
  [ -n "$st" ] || return 1
  printf '%s:%s\n' "$pid" "$st"
}

proc_age_secs() {
  local pid="$1" age
  age="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')" || return 1
  [ -n "$age" ] || return 1
  printf '%s\n' "$age"
}

proc_cmd() { ps -o args= -p "$1" 2>/dev/null | head -1; }

# Kill a whole process tree, children first, so a parent cannot respawn them.
kill_tree() {
  local root="$1" sig="${2:--TERM}" kids k
  kids="$(pgrep -P "$root" 2>/dev/null || true)"
  for k in $kids; do kill_tree "$k" "$sig"; done
  kill "$sig" "$root" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Phase A: Playwright MCP browsers
# ---------------------------------------------------------------------------

# Root browser processes (not --type= helpers) using an ms-playwright-mcp profile.
pw_browser_roots() {
  # shellcheck disable=SC2009 # need pid AND full args to match the profile path
  ps -eo pid=,args= 2>/dev/null \
    | grep -F 'ms-playwright-mcp' \
    | grep -v -- '--type=' \
    | grep -v 'mcp-reaper' \
    | grep -vE '(bin/playwright-mcp|@playwright/mcp)' \
    | awk '{print $1}'
}
# NOTE the server-binary exclusion above. It must match the SERVER only, never
# the profile path: the cache dir is named "ms-playwright-mcp", so a loose
# 'playwright-mcp' pattern also matches every browser's --user-data-dir and
# silently disables this whole phase. Today the server's argv is just
# "node .../bin/playwright-mcp" with no profile path, so it cannot match. But
# adding an explicit --user-data-dir to the MCP server args would put the path
# in the SERVER's argv, and without this guard the reaper would classify the
# live server as an orphaned browser and kill it.

pw_profile_of() {
  # Processes come and go between the ps snapshot and this read; a vanished
  # pid is normal, not an error.
  [ -r "/proc/$1/cmdline" ] || return 0
  # Chrome rewrites its own argv, so /proc/PID/cmdline is NOT reliably
  # NUL-separated per argument: it is often one space-separated blob. Splitting
  # on NUL and anchoring with ^--user-data-dir= therefore matches nothing and
  # silently returns empty for EVERY browser, which then makes every profile
  # compare equal to every other. Normalise to spaces and extract by pattern.
  { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null || true; } \
    | grep -oE -- '--user-data-dir=[^ ]+' \
    | head -1 \
    | sed 's/^--user-data-dir=//'
}

# True if some ancestor is a live playwright-mcp server process.
pw_has_live_owner() {
  local pid="$1" hops=0 args
  while [ "$pid" != "1" ] && [ -n "$pid" ] && [ "$hops" -lt 12 ]; do
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" || return 1
    [ -n "$pid" ] || return 1
    args="$(proc_cmd "$pid")"
    case "$args" in
      *playwright-mcp*|*'@playwright/mcp'*) return 0 ;;
    esac
    hops=$((hops + 1))
  done
  return 1
}

# Strip session-restore state so a killed browser cannot come back into the
# same page. This is what turned a single wedged WebGL tab into a restore loop:
# kill -> exit_type=Crashed -> relaunch restores the tab -> pins the CPU again.
scrub_restore_state() {
  local profile="$1"
  [ -n "$profile" ] || return 0
  [ -d "$profile/Default" ] || return 0
  rm -f "$profile/Default/Sessions/"* 2>/dev/null || true
  rm -f "$profile/Default/Tabs_"* 2>/dev/null || true
  if [ -f "$profile/Default/Preferences" ]; then
    python3 - "$profile/Default/Preferences" <<'PYEOF' 2>/dev/null || true
import json, sys
p = sys.argv[1]
with open(p) as fh:
    j = json.load(fh)
j.setdefault("profile", {})["exit_type"] = "Normal"
j["profile"]["exited_cleanly"] = True
with open(p, "w") as fh:
    json.dump(j, fh)
PYEOF
  fi
  log "    scrubbed restore state in $profile"
}

# Instantaneous CPU% of a pid, sampled over SPIN_SAMPLE_SECS.
cpu_pct_over() {
  local pid="$1" secs="$2" t1 t2 hz
  hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
  t1="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)" || return 1
  sleep "$secs"
  t2="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null)" || return 1
  awk -v a="$t1" -v b="$t2" -v s="$secs" -v hz="$hz" 'BEGIN{printf "%d", ((b-a)/hz/s)*100}'
}

phase_a() {
  local roots root profile owner_ok gpu pct killed=0
  roots="$(pw_browser_roots || true)"
  [ -n "$roots" ] || { log "phase A: no playwright browsers running"; return 0; }

  for root in $roots; do
    [ -d "/proc/$root" ] || continue
    profile="$(pw_profile_of "$root")"
    # Never act on a browser we cannot identify. An empty profile would also
    # compare equal to every other empty profile below.
    [ -n "$profile" ] || { log "phase A: pid=$root has no readable profile, skipping"; continue; }

    owner_ok=0
    pw_has_live_owner "$root" && owner_ok=1

    if [ "$owner_ok" -eq 0 ]; then
      log "phase A: ORPHAN browser pid=$root profile=${profile:-?} (no live playwright-mcp ancestor)"
      if [ "$DRY" = "1" ]; then
        log "    dry run, not killing"
      else
        kill_tree "$root" -KILL
        scrub_restore_state "$profile"
        killed=$((killed + 1))
      fi
      continue
    fi

    # Owner is alive, so only a pathological spin justifies killing it.
    gpu="$(pgrep -f -- '--type=gpu-process' 2>/dev/null | while read -r g; do
             gp="$(pw_profile_of "$g")"
             [ -n "$gp" ] || continue
             if [ "$gp" = "$profile" ]; then printf '%s\n' "$g"; fi
           done | head -1)"
    [ -n "$gpu" ] || continue

    pct="$(cpu_pct_over "$gpu" "$SPIN_SAMPLE_SECS" 2>/dev/null || echo 0)"
    if [ "${pct:-0}" -ge "$SPIN_PCT" ]; then
      log "phase A: WEDGED browser pid=$root gpu=$gpu at ${pct}% CPU (threshold ${SPIN_PCT}%) profile=${profile:-?}"
      log "    headless SwiftShader rendering WebGL on CPU; killing browser and clearing restore state"
      if [ "$DRY" = "1" ]; then
        log "    dry run, not killing"
      else
        kill_tree "$root" -KILL
        scrub_restore_state "$profile"
        killed=$((killed + 1))
      fi
    fi
  done
  log "phase A: killed $killed browser(s)"
}

# GC abandoned profile dirs. Only touches dirs untouched for PROFILE_GC_DAYS
# that no running browser has open.
phase_a_gc() {
  local live d freed=0 count=0
  [ -d "$PW_CACHE" ] || return 0
  live="$(pw_browser_roots | while read -r p; do pw_profile_of "$p"; done || true)"

  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$live" in *"$d"*) continue ;; esac
    count=$((count + 1))
    if [ "$DRY" = "1" ]; then
      log "phase A gc: would remove $d"
    else
      rm -rf "$d" 2>/dev/null || true
      freed=$((freed + 1))
    fi
  done < <(find "$PW_CACHE" -maxdepth 1 -type d -name 'mcp-chrome-*' -mtime "+$PROFILE_GC_DAYS" 2>/dev/null)

  [ "$count" -gt 0 ] && log "phase A gc: removed $freed of $count stale profile dir(s)"
  return 0
}

# ---------------------------------------------------------------------------
# Phase B: idle MCP servers under codex app-server
# ---------------------------------------------------------------------------

app_servers() { pgrep -f 'codex .*app-server' 2>/dev/null || true; }

# Fleets: codex spawns one batch of ~14 MCP servers per conversation, all
# within about a second of each other. Measured on kronos, a fleet whose
# conversation has ended looks like this:
#
#   inert   context7 playwright nixos gsc slack magicui shadcn ... (10 of 14)
#   ACTIVE  server.cjs, some server.mjs                            ( 4 of 14)
#
# Those last few are active in 7 of 7 DEAD fleets, so their traffic is a
# self-generated timer, not a client. That is why liveness is judged per fleet
# with a ratio rather than per process: requiring every member to be inert
# would never fire, and reaping only the inert members would leave the
# self-chattering ones leaking forever.
FLEET_WINDOW_SECS="${MCP_REAPER_FLEET_WINDOW:-3}"
FLEET_MIN_SIZE="${MCP_REAPER_FLEET_MIN_SIZE:-5}"
FLEET_INERT_PCT="${MCP_REAPER_FLEET_INERT_PCT:-80}"

proc_start_epoch() {
  ps -o lstart= -p "$1" 2>/dev/null | { read -r l; date -d "$l" +%s 2>/dev/null; }
}

phase_b() {
  local app kids pid key age rchar prev_rchar prev_zero_since now e
  local new_state fleet_map fleet_group killed=0 candidates=0 tracked=0
  now="$(now_epoch)"
  new_state="$(mktemp)"
  fleet_map="$(mktemp)"
  fleet_group="$(mktemp)"

  for app in $(app_servers); do
    kids="$(ps --ppid "$app" -o pid= 2>/dev/null || true)"
    for pid in $kids; do
      [ -d "/proc/$pid" ] || continue
      key="$(proc_key "$pid")" || continue
      age="$(proc_age_secs "$pid")" || continue
      rchar="$(awk '/^rchar/{print $2}' "/proc/$pid/io" 2>/dev/null)" || continue
      [ -n "$rchar" ] || continue
      tracked=$((tracked + 1))

      prev_rchar=""
      prev_zero_since=""
      if [ -f "$STATE_FILE" ]; then
        local line
        line="$(grep -F "$key	" "$STATE_FILE" 2>/dev/null | head -1 || true)"
        if [ -n "$line" ]; then
          prev_rchar="$(printf '%s' "$line" | cut -f2)"
          prev_zero_since="$(printf '%s' "$line" | cut -f3)"
        fi
      fi

      # Any traffic at all resets the streak.
      if [ -z "$prev_rchar" ] || [ "$rchar" != "$prev_rchar" ]; then
        printf '%s\t%s\t%s\n' "$key" "$rchar" "$now" >> "$new_state"
        continue
      fi

      # rchar unchanged since last run: carry the streak start forward.
      : "${prev_zero_since:=$now}"
      printf '%s\t%s\t%s\n' "$key" "$rchar" "$prev_zero_since" >> "$new_state"

      # Record fleet membership and inertness; the kill decision is made per
      # fleet after every process has been measured.
      local inert=0
      if [ "$age" -ge "$IDLE_MIN_AGE_SECS" ] && \
         [ $((now - prev_zero_since)) -ge "$IDLE_ZERO_SECS" ]; then
        inert=1
      fi
      printf '%s\t%s\t%s\n' "$(proc_start_epoch "$pid")" "$pid" "$inert" >> "$fleet_map"
    done
  done

  sort -u "$new_state" > "$STATE_FILE" 2>/dev/null || cp "$new_state" "$STATE_FILE"
  rm -f "$new_state"

  # Cluster spawn epochs into fleets, then judge each fleet as a unit.
  local epochs prev_e=-999 fleet_key=""
  epochs="$(cut -f1 "$fleet_map" | sort -un)"
  : > "$fleet_group"
  for e in $epochs; do
    if [ $((e - prev_e)) -gt "$FLEET_WINDOW_SECS" ]; then fleet_key="$e"; fi
    printf '%s\t%s\n' "$e" "$fleet_key" >> "$fleet_group"
    prev_e="$e"
  done

  local fk total inert_n pct pids
  # shellcheck disable=SC2013 # keys are bare epochs (no spaces); a `while read`
  # pipeline would run the body in a subshell and lose the $killed cap counter
  for fk in $(cut -f2 "$fleet_group" | sort -un); do
    pids="$(awk -v g="$fleet_group" -v k="$fk" '
      BEGIN { while ((getline l < g) > 0) { split(l, a, "\t"); if (a[2] == k) keep[a[1]] = 1 } }
      ($1 in keep) { print $2 }' "$fleet_map")"
    total="$(printf '%s\n' "$pids" | grep -c . || true)"
    [ "$total" -ge "$FLEET_MIN_SIZE" ] || continue
    inert_n="$(awk -v g="$fleet_group" -v k="$fk" '
      BEGIN { while ((getline l < g) > 0) { split(l, a, "\t"); if (a[2] == k) keep[a[1]] = 1 } }
      ($1 in keep) && $3 == 1 { n++ } END { print n+0 }' "$fleet_map")"
    pct=$(( inert_n * 100 / total ))
    [ "$pct" -ge "$FLEET_INERT_PCT" ] || continue

    candidates=$((candidates + 1))
    log "phase B: DEAD FLEET spawned $(date -d "@$fk" '+%H:%M:%S') :: ${inert_n}/${total} inert (${pct}%, threshold ${FLEET_INERT_PCT}%)"
    for pid in $pids; do
      [ -d "/proc/$pid" ] || continue
      if [ "$killed" -ge "$MAX_KILLS" ]; then
        log "    hit MAX_KILLS=$MAX_KILLS, leaving the rest for the next run"
        break
      fi
      if [ "$ARM_IDLE" != "1" ] || [ "$DRY" = "1" ]; then
        log "    would kill pid=$pid :: $(proc_cmd "$pid" | cut -c1-60)"
      else
        kill_tree "$pid" -TERM
        killed=$((killed + 1))
      fi
    done
  done

  rm -f "$fleet_map" "$fleet_group"
  log "phase B: tracked $tracked, $candidates dead fleet(s), killed $killed"
}

# ---------------------------------------------------------------------------

log "mcp-reaper starting (DRY=$DRY ARM_IDLE=$ARM_IDLE)"
phase_a || log "phase A failed, continuing"
phase_a_gc || log "phase A gc failed, continuing"
phase_b || log "phase B failed, continuing"
log "mcp-reaper done"
