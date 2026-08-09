#!/usr/bin/env bash
# Kronos terminal banner — the host wordmark, drawn once per interactive shell.
#
# Replaces the old `ff` cascade, which replayed fastfetch line-by-line with a
# sleep between each one: every new terminal paid an animation plus a full
# system probe before it was usable.
#
# This is deliberately dumb by comparison. The art is a literal heredoc, the
# only work is one awk pass to colour it, and nothing is probed — no uptime,
# no package count, no GPU query. It prints and gets out of the way.
#
# Colours are injected from lib/palette.nix at build time (@from@ / @to@ are
# "r;g;b" triplets), so the banner follows Ouranos without a second source of
# truth. Deps: awk only.
set -u

# Nothing to draw when piped, redirected, or on a dumb terminal.
[ -t 1 ] || exit 0
[ "${TERM:-dumb}" != "dumb" ] || exit 0

pad="  "

# Left-to-right gradient across the widest line, so the sweep stays square
# regardless of which row a character sits on.
grad() {
  awk -v from="@from@" -v to="@to@" '
  function part(s, i,   n) { n = split(s, a, ";"); return a[i] + 0 }
  function lerp(a, b, t) { return a + (b - a) * t }
  { lines[NR] = $0; if (length($0) > maxw) maxw = length($0) }
  END {
    for (i = 1; i <= NR; i++) {
      n = length(lines[i]); out = ""
      for (j = 1; j <= n; j++) {
        f = (maxw > 1) ? (j - 1) / (maxw - 1) : 0
        r = lerp(part(from,1), part(to,1), f)
        g = lerp(part(from,2), part(to,2), f)
        b = lerp(part(from,3), part(to,3), f)
        out = out sprintf("\033[1;38;2;%d;%d;%dm%s", int(r+0.5), int(g+0.5), int(b+0.5), substr(lines[i], j, 1))
      }
      printf "%s\033[0m\n", out
    }
  }'
}

echo
# figlet "slant", baked in rather than generated: no figlet dependency at
# startup and the output can never drift with a font-package update.
cat <<'ART' | sed "s/^/$pad/" | grad
    __ __ ____  ____  _   ______  _____
   / //_// __ \/ __ \/ | / / __ \/ ___/
  / ,<  / /_/ / / / /  |/ / / / /\__ \
 / /| |/ _, _/ /_/ / /|  / /_/ /___/ /
/_/ |_/_/ |_|\____/_/ |_/\____//____/
ART

# Hairline rule, matched to the wordmark's width and fading along the same
# cobalt ramp. Coloured in whole segments rather than per character: the box
# glyph is multibyte and awk's substr() is byte-based, so running it through
# grad() above splits it mid-sequence — mojibake plus an "Invalid multibyte
# data" warning on every single shell start.
rule() {
  local width=38 segs=8 i seg from_r from_g from_b to_r to_g to_b r g b f
  IFS=';' read -r from_r from_g from_b <<<"@from@"
  IFS=';' read -r to_r to_g to_b <<<"@to@"
  printf '%s' "$pad"
  for ((i = 0; i < segs; i++)); do
    f=$(((i * 100) / (segs - 1)))
    r=$((from_r + (to_r - from_r) * f / 100))
    g=$((from_g + (to_g - from_g) * f / 100))
    b=$((from_b + (to_b - from_b) * f / 100))
    seg=$(printf '%*s' $((width / segs)) '')
    printf '\033[38;2;%d;%d;%dm%s' "$r" "$g" "$b" "${seg// /─}"
  done
  printf '\033[0m\n'
}
rule
echo
