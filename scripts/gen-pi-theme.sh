#!/usr/bin/env bash
# gen-pi-theme.sh — Reads your Stylix base16 YAML and generates a pi-coding-agent theme.
# Usage: gen-pi-theme.sh [path-to-base16.yaml]
#
# If no argument given, auto-detects from your Stylix NixOS config.

set -euo pipefail

SCHEME_FILE="${1:-}"

# Auto-detect from Stylix config if no arg
if [[ -z "$SCHEME_FILE" ]]; then
  STYLIX_NIX="$HOME/dotfiles/modules/stylix.nix"
  if [[ -f "$STYLIX_NIX" ]]; then
    # Extract the scheme filename (e.g., rose-pine.yaml)
    SCHEME_NAME=$(grep 'base16Scheme' "$STYLIX_NIX" | sed 's/.*\/\([^"]*\.yaml\).*/\1/')
    if [[ -n "$SCHEME_NAME" ]]; then
      SCHEME_FILE=$(find /nix/store -name "$SCHEME_NAME" -path "*base16-schemes*" 2>/dev/null | head -1)
    fi
  fi
fi

if [[ -z "$SCHEME_FILE" || ! -f "$SCHEME_FILE" ]]; then
  echo "Error: Could not find base16 scheme. Pass path as argument." >&2
  exit 1
fi

# Parse base16 colors from YAML (handles both quoted and unquoted hex values)
get_color() {
  grep "  $1:" "$SCHEME_FILE" | sed 's/.*"\(#[0-9a-fA-F]\{6\}\)".*/\1/' | sed 's/.*\(#[0-9a-fA-F]\{6\}\).*/\1/'
}

base00=$(get_color base00)  # bg
base01=$(get_color base01)  # bg lighter
base02=$(get_color base02)  # selection
base03=$(get_color base03)  # comments, muted
base04=$(get_color base04)  # dark fg
base05=$(get_color base05)  # fg
base06=$(get_color base06)  # light fg
base07=$(get_color base07)  # lightest / alt
base08=$(get_color base08)  # red
base09=$(get_color base09)  # orange
base0A=$(get_color base0A)  # yellow
base0B=$(get_color base0B)  # green
base0C=$(get_color base0C)  # cyan
base0D=$(get_color base0D)  # blue/purple
base0E=$(get_color base0E)  # magenta
base0F=$(get_color base0F)  # brown/dark

SCHEME_PRETTY=$(grep "^name:" "$SCHEME_FILE" | sed 's/name: *"\{0,1\}\(.*\)"\{0,1\}/\1/' | tr -d '"')

PI_OUTPUT="$HOME/.pi/agent/themes/stylix.json"
OMP_OUTPUT="$HOME/.omp/agent/themes/stylix.json"

mkdir -p "$(dirname "$PI_OUTPUT")" "$(dirname "$OMP_OUTPUT")"

# Generate theme JSON into a variable, then write to both locations
THEME_JSON=$(cat <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "stylix",
  "vars": {
    "bg":          "$base00",
    "bgLight":     "$base01",
    "bgLighter":   "$base02",
    "muted":       "$base03",
    "dimFg":       "$base04",
    "fg":          "$base05",
    "fgBright":    "$base06",
    "alt":         "$base07",
    "red":         "$base08",
    "orange":      "$base09",
    "yellow":      "$base0A",
    "green":       "$base0B",
    "cyan":        "$base0C",
    "accent":      "$base0D",
    "magenta":     "$base0E",
    "dark":        "$base0F"
  },
  "colors": {
    "accent":              "accent",
    "border":              "bgLighter",
    "borderAccent":        "accent",
    "borderMuted":         "bgLight",
    "success":             "green",
    "error":               "red",
    "warning":             "orange",
    "muted":               "muted",
    "dim":                 "dimFg",
    "text":                "fg",
    "thinkingText":        "muted",

    "selectedBg":          "bgLighter",
    "userMessageBg":       "bgLight",
    "userMessageText":     "fg",
    "customMessageBg":     "bgLight",
    "customMessageText":   "fg",
    "customMessageLabel":  "accent",
    "toolPendingBg":       "bgLight",
    "toolSuccessBg":       "bgLight",
    "toolErrorBg":         "bgLight",
    "toolTitle":           "cyan",
    "toolOutput":          "dimFg",

    "mdHeading":           "accent",
    "mdLink":              "cyan",
    "mdLinkUrl":           "muted",
    "mdCode":              "yellow",
    "mdCodeBlock":         "fg",
    "mdCodeBlockBorder":   "bgLighter",
    "mdQuote":             "muted",
    "mdQuoteBorder":       "bgLighter",
    "mdHr":                "bgLighter",
    "mdListBullet":        "accent",

    "toolDiffAdded":       "green",
    "toolDiffRemoved":     "red",
    "toolDiffContext":      "muted",

    "syntaxComment":       "muted",
    "syntaxKeyword":       "accent",
    "syntaxFunction":      "cyan",
    "syntaxVariable":      "fg",
    "syntaxString":        "green",
    "syntaxNumber":        "orange",
    "syntaxType":          "yellow",
    "syntaxOperator":      "dimFg",
    "syntaxPunctuation":   "dimFg",

    "thinkingOff":         "bgLighter",
    "thinkingMinimal":     "muted",
    "thinkingLow":         "dimFg",
    "thinkingMedium":      "cyan",
    "thinkingHigh":        "accent",
    "thinkingXhigh":       "magenta",

    "bashMode":            "orange"
  },
  "export": {
    "pageBg":   "$base00",
    "cardBg":   "$base01",
    "infoBg":   "$base02"
  }
}
EOF
)

echo "$THEME_JSON" > "$PI_OUTPUT"
echo "$THEME_JSON" > "$OMP_OUTPUT"

echo "Generated theme from '$SCHEME_PRETTY' →"
echo "  pi:  $PI_OUTPUT"
echo "  omp: $OMP_OUTPUT"
