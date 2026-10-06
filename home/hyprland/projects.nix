{
  config,
  pkgs,
  ...
}:
# Project launcher (Super+O): pick a repo under ~/projects, land in its herdr
# workspace. An open workspace is focused; a new one is laid out as
#
#   ┌──────────────── nvim ─────────────┬──── claude ────┐
#   │                                   ├──── codex ─────┤
#   ├──────────────── shell ────────────┴────────────────┤
#
# after Omarchy's hdl (default/bash/fns/herdr), but driven from a picker and
# reattaching instead of rebuilding. Panes open in the repo, so direnv loads
# its flake shell before nvim and the agents start. herdr recognises the
# agents by itself; that state feeds the cockpit.
#
# herdr lives in its own ghostty window class so the launcher can find it:
# ghostty runs every window in one process, so a pid can't tell them apart.
let
  cfgHome = config.xdg.configHome;
  home = config.home.homeDirectory;
  jq = "${pkgs.jq}/bin/jq";
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel --dmenu --config ${cfgHome}/fuzzel/hypr.ini";
  herdrClass = "dev.ouranos.herdr";

  # Bring the herdr window up (attaching to the running session if needed).
  herdrWindow = pkgs.writeShellScriptBin "ouranos-herdr" ''
    exec ouranos-focus-or-launch '^${herdrClass}$' ghostty --class=${herdrClass} -e herdr
  '';

  project = pkgs.writeShellScriptBin "ouranos-project" ''
    set -o pipefail
    WS=$(herdr workspace list 2>/dev/null | ${jq} -c '[.result.workspaces[] | {label, id: .workspace_id}]' || echo '[]')

    # Repos newest-commit first. 137 repos scan in ~0.3s.
    LIST=$( { ${pkgs.fd}/bin/fd -H -I -t d --max-depth 4 -E node_modules -E .direnv '^\.git$' ${home}/projects
              echo ${home}/nix-config/.git; } 2>/dev/null \
      | while read -r g; do
          d=''${g%/}; d=''${d%/.git}
          printf '%s\t%s\t%s\n' "$(git -C "$d" log -1 --format=%ct 2>/dev/null || echo 0)" "$d" \
            "$(git -C "$d" branch --show-current 2>/dev/null)"
        done | sort -rn)

    ROWS=$(while IFS=$'\t' read -r ts d br; do
        name=''${d#${home}/projects/}; name=''${name#${home}/}
        open=$(${jq} -r --arg l "$(basename "$d")" 'map(select(.label == $l)) | if length > 0 then "open" else "" end' <<<"$WS")
        printf '%-34s %-26s %s\n' "$name" "''${br:0:26}" "$open"
      done <<<"$LIST")
    SEL=$(printf '%s\n' "$ROWS" | ${fuzzel} --index --prompt="projects › " --width 72) || exit 0
    DIR=$(sed -n "$((SEL + 1))p" <<<"$LIST" | cut -f2)
    NAME=$(basename "$DIR")

    ouranos-herdr
    ID=$(${jq} -r --arg l "$NAME" 'map(select(.label == $l))[0].id // empty' <<<"$WS")
    if [ -n "$ID" ]; then
      herdr workspace focus "$ID" >/dev/null
      exit 0
    fi

    # New workspace: shell at the bottom, then nvim | agents above it.
    ROOT=$(herdr workspace create --cwd "$DIR" --label "$NAME" --focus | ${jq} -r .result.root_pane.pane_id)
    TOP=$ROOT
    SHELL_P=$(herdr pane split "$ROOT" --direction down --ratio 0.8 --cwd "$DIR" --no-focus | ${jq} -r .result.pane.pane_id)
    RIGHT=$(herdr pane split "$TOP" --direction right --ratio 0.6 --cwd "$DIR" --no-focus | ${jq} -r .result.pane.pane_id)
    CODEX=$(herdr pane split "$RIGHT" --direction down --ratio 0.5 --cwd "$DIR" --no-focus | ${jq} -r .result.pane.pane_id)
    herdr pane run "$TOP" nvim . >/dev/null
    herdr pane run "$RIGHT" claude >/dev/null
    herdr pane run "$CODEX" codex >/dev/null
    : "$SHELL_P" # the shell pane stays a plain prompt
  '';
in
{
  home.packages = [
    herdrWindow
    project
  ];
}
