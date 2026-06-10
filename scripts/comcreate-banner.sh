#!/usr/bin/env bash
# ComCreate terminal banner — brand gradient from comcreate.io's logo:
# cyan #5ed7e8 → purple #8662fc (src/lib/components/Footer.svelte gradient stops).
# Rendered on each new interactive terminal via the fish/bash greeting.
# Deps (resolved from the interactive PATH): figlet, awk, tput.
set -u

grad() { # mode=fg|bg ; reads stdin, colors each column across the widest line
  local mode="$1"
  awk -v mode="$mode" '
  function lerp(a, b, t) { return a + (b - a) * t }
  function col(f,   r, g, b) {       # cyan #5ed7e8 -> purple #8662fc
    if (f < 0) f = 0; if (f > 1) f = 1
    r = lerp(94, 134, f); g = lerp(215, 98, f); b = lerp(232, 252, f)
    return sprintf("%d;%d;%d", int(r + 0.5), int(g + 0.5), int(b + 0.5))
  }
  { lines[NR] = $0; L = length($0); if (L > maxw) maxw = L }
  END {
    p = (mode == "bg") ? 48 : 38
    for (i = 1; i <= NR; i++) {
      n = length(lines[i]); out = ""
      for (j = 1; j <= n; j++) {
        f = (maxw > 1) ? (j - 1) / (maxw - 1) : 0
        out = out sprintf("\033[%d;2;%sm%s", p, col(f), substr(lines[i], j, 1))
      }
      printf "%s\033[0m\n", out
    }
  }'
}

cols=$(tput cols 2>/dev/null || echo 80)
w=$(( cols < 92 ? cols : 92 )); pad="  "
CY='\033[1;38;2;94;215;232m'   # comcreate cyan   #5ed7e8
PU='\033[1;38;2;134;98;252m'   # comcreate purple #8662fc
C='\033[38;2;232;228;223m'     # cream            #e8e4df
M='\033[38;2;107;101;93m'      # muted            #6b655d
R='\033[0m'

echo
printf '%s' "$pad"; printf '%*s' "$w" '' | grad bg; echo
echo
# slant font = italic wordmark
figlet -f slant -w 200 "COMCREATE" | sed "s/^/$pad/" | grad fg
echo
printf "%s${CY}⚡ ENGINEERING-FIRST DIGITAL AGENCY${R}\n" "$pad"
printf "%s${PU}comcreate.io${R}${M}  ▸  ${R}${C}Built on the modern stack.${R}\n" "$pad"
echo
printf "%s${M}“Proof, not promises.”${R}\n" "$pad"
echo
printf '%s' "$pad"; printf '%*s' "$w" '' | grad bg; echo
echo
