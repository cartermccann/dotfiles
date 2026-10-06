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

  # ouranos-project               pick a repo and open it
  # ouranos-project --pick        print the picked repo, open nothing
  # ouranos-project --open <dir>  open <dir> without the picker
  project = pkgs.writeShellScriptBin "ouranos-project" ''
    set -o pipefail
    WS=$(herdr workspace list 2>/dev/null | ${jq} -c '[.result.workspaces[] | {label, id: .workspace_id}]' || echo '[]')

    # Repos newest-commit first (137 repos scan in ~0.5s); prints the pick.
    pick() {
      local list rows sel
      list=$( { ${pkgs.fd}/bin/fd -H -I -t d --max-depth 4 -E node_modules -E .direnv '^\.git$' ${home}/projects
                echo ${home}/nix-config/.git; } 2>/dev/null \
        | while read -r g; do
            d=''${g%/}; d=''${d%/.git}
            printf '%s\t%s\t%s\n' "$(git -C "$d" log -1 --format=%ct 2>/dev/null || echo 0)" "$d" \
              "$(git -C "$d" branch --show-current 2>/dev/null)"
          done | sort -rn)
      rows=$(while IFS=$'\t' read -r _ d br; do
          name=''${d#${home}/projects/}; name=''${name#${home}/}
          open=$(${jq} -r --arg l "$(basename "$d")" 'map(select(.label == $l)) | if length > 0 then "open" else "" end' <<<"$WS")
          printf '%-34s %-26s %s\n' "$name" "''${br:0:26}" "$open"
        done <<<"$list")
      sel=$(printf '%s\n' "$rows" | ${fuzzel} --index --prompt="''${PROMPT:-projects › }" --width 72) || return 1
      sed -n "$((sel + 1))p" <<<"$list" | cut -f2
    }

    # Focus the repo's workspace, or create it with the layout.
    open_dir() {
      local dir=$1 name id root right codex
      name=$(basename "$dir")
      ouranos-herdr
      id=$(${jq} -r --arg l "$name" 'map(select(.label == $l))[0].id // empty' <<<"$WS")
      if [ -n "$id" ]; then
        herdr workspace focus "$id" >/dev/null
        return
      fi
      root=$(herdr workspace create --cwd "$dir" --label "$name" --focus | ${jq} -r .result.root_pane.pane_id)
      herdr pane split "$root" --direction down --ratio 0.8 --cwd "$dir" --no-focus >/dev/null # shell strip
      right=$(herdr pane split "$root" --direction right --ratio 0.6 --cwd "$dir" --no-focus | ${jq} -r .result.pane.pane_id)
      codex=$(herdr pane split "$right" --direction down --ratio 0.5 --cwd "$dir" --no-focus | ${jq} -r .result.pane.pane_id)
      herdr pane run "$root" nvim . >/dev/null
      herdr pane run "$right" claude >/dev/null
      herdr pane run "$codex" codex >/dev/null
    }

    case "''${1:-}" in
      --pick) pick ;;
      --open) open_dir "$2" ;;
      *) dir=$(pick) && open_dir "$dir" ;;
    esac
  '';
in
{
  home.packages = [
    herdrWindow
    project
  ];
}
