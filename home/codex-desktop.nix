{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  overlayDir = "${homeDir}/projects/input-linux/codex-desktop-overlay";
  appId = "codex-desktop";

  # The vendored Electron in the overlay is an upstream prebuilt binary, not a
  # Nix build, so it needs a runtime library path handed to it. Keeping that
  # path here — rather than baked as literal store paths inside the overlay's
  # start.sh, which is how it used to work — makes these libraries real
  # dependencies of the home-manager generation. They are therefore GC-rooted
  # and follow nixpkgs bumps, instead of dangling on the next
  # nix-collect-garbage and killing the app with a missing libnspr4.so.
  # start.sh consumes this as CODEX_LINUX_NIX_LIBRARY_PATH; see the comment it
  # carries around its `export LD_LIBRARY_PATH=` line.
  nixLibraryPath = lib.makeLibraryPath (
    with pkgs;
    [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libglvnd
      libnotify
      libusb1 # Codex Micro Linux HID runtime
      libxcrypt
      libxkbcommon
      mesa
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      systemd
      wayland
      zlib
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXScrnSaver
      xorg.libXtst
      xorg.libxcb
    ]
  );

  codexDesktopGuard = pkgs.writeShellApplication {
    name = "codex-desktop-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      overlay_dir=${lib.escapeShellArg overlayDir}
      app_id=${lib.escapeShellArg appId}
      nix_library_path=${lib.escapeShellArg nixLibraryPath}
      # These must stay in sync with the fallbacks in the overlay's start.sh,
      # which applies the same limits to the same scope. Both paths racing with
      # different values is nondeterministic: whichever set-property lands last
      # wins. Exporting them makes start.sh reuse these instead of its own
      # fallbacks, so the race becomes a no-op.
      #
      # Do not lower these without reading the rationale in start.sh: terminals
      # launched from the app inherit this scope, so the budget covers real
      # build workloads, not just Electron. An 8G MemoryHigh against a ~20G
      # working set kept the cgroup in sustained reclaim, and systemd-oomd
      # killed all 431 processes in the scope while the box still had 44G free.
      # MemoryHigh is a throttle; MemoryMax is the wall. earlyoom/systemd-oomd
      # are the runaway backstop, not these.
      memory_high="''${CODEX_LINUX_MEMORY_HIGH:-28G}"
      memory_max="''${CODEX_LINUX_MEMORY_MAX:-32G}"
      tasks_max="''${CODEX_LINUX_TASKS_MAX:-8000}"
      export CODEX_LINUX_MEMORY_HIGH="$memory_high"
      export CODEX_LINUX_MEMORY_MAX="$memory_max"
      export CODEX_LINUX_TASKS_MAX="$tasks_max"
      launcher_pid=""
      owned_scope=""

      scope_name_is_valid() {
        local unit="$1"
        local prefix="app-$app_id-"
        local suffix

        [[ "$unit" == "$prefix"*.scope ]] || return 1
        suffix="''${unit#"$prefix"}"
        suffix="''${suffix%.scope}"
        [[ "$suffix" =~ ^[0-9]+$ ]]
      }

      scope_process_file() {
        local unit="$1"
        local control_group

        scope_name_is_valid "$unit" || return 1
        control_group="$(systemctl --user show "$unit" -p ControlGroup --value 2>/dev/null || true)"
        [ -n "$control_group" ] || return 1
        case "$control_group" in
          */app.slice/"$unit") ;;
          *) return 1 ;;
        esac
        [ -r "/sys/fs/cgroup''${control_group}/cgroup.procs" ] || return 1
        printf '%s\n' "/sys/fs/cgroup''${control_group}/cgroup.procs"
      }

      pid_is_primary_electron() {
        local pid="$1"
        local executable arg

        [[ "$pid" =~ ^[0-9]+$ ]] || return 1
        [ -r "/proc/$pid/cmdline" ] || return 1
        executable="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
        [ "$executable" = "$overlay_dir/electron" ] || return 1
        while IFS= read -r -d "" arg; do
          [[ "$arg" == --type=* ]] && return 1
        done < "/proc/$pid/cmdline"
        return 0
      }

      scope_has_primary_electron() {
        local unit="$1"
        local process_file pid

        process_file="$(scope_process_file "$unit")" || return 1
        while IFS= read -r pid; do
          pid_is_primary_electron "$pid" && return 0
        done < "$process_file"
        return 1
      }

      find_primary_scope() {
        local unit rest

        while read -r unit rest; do
          [ -n "$unit" ] || continue
          scope_name_is_valid "$unit" || continue
          if scope_has_primary_electron "$unit"; then
            printf '%s\n' "$unit"
            return 0
          fi
        done < <(
          systemctl --user list-units \
            --type=scope \
            --state=active \
            --plain \
            --no-legend \
            "app-$app_id-*.scope" 2>/dev/null || true
        )
        return 1
      }

      stop_stale_scopes() {
        local unit rest

        while read -r unit rest; do
          [ -n "$unit" ] || continue
          scope_name_is_valid "$unit" || continue
          scope_has_primary_electron "$unit" && continue
          echo "Stopping stale Codex application scope $unit"
          systemctl --user stop "$unit" || \
            echo "WARN: could not stop stale Codex application scope $unit" >&2
        done < <(
          systemctl --user list-units \
            --all \
            --type=scope \
            --plain \
            --no-legend \
            "app-$app_id-*.scope" 2>/dev/null || true
        )
      }

      apply_scope_limits() {
        local unit="$1"

        [[ "$memory_high" =~ ^([0-9]+([KMGTPE])?|infinity)$ ]] || return 1
        [[ "$memory_max" =~ ^([0-9]+([KMGTPE])?|infinity)$ ]] || return 1
        [[ "$tasks_max" =~ ^[0-9]+$ ]] || return 1
        systemctl --user set-property --runtime "$unit" \
          "MemoryHigh=$memory_high" \
          "MemoryMax=$memory_max" \
          "TasksMax=$tasks_max"
        echo "Codex scope limits: unit=$unit memory_high=$memory_high memory_max=$memory_max tasks_max=$tasks_max"
      }

      # shellcheck disable=SC2329 # Invoked indirectly by the trap below.
      cleanup() {
        local status=$?
        trap - EXIT INT TERM HUP

        if [ -n "$owned_scope" ] && systemctl --user is-active --quiet "$owned_scope" 2>/dev/null; then
          echo "Stopping owned Codex application scope $owned_scope"
          systemctl --user stop --no-block "$owned_scope" 2>/dev/null || true
        fi
        if [ -n "$launcher_pid" ] && kill -0 "$launcher_pid" 2>/dev/null; then
          kill "$launcher_pid" 2>/dev/null || true
        fi
        exit "$status"
      }

      [ -x "$overlay_dir/start.sh" ] || {
        echo "Codex Desktop overlay is missing: $overlay_dir/start.sh" >&2
        exit 1
      }

      export CODEX_LINUX_NIX_LIBRARY_PATH="$nix_library_path"
      # An app update can replace start.sh with a build that re-bakes literal
      # store paths and ignores the variable above. Keep the app launchable in
      # that case by setting LD_LIBRARY_PATH ourselves — the launcher appends
      # the inherited value, so the fresh paths still resolve — and say loudly
      # that the launcher wants re-patching.
      if ! grep -qF CODEX_LINUX_NIX_LIBRARY_PATH "$overlay_dir/start.sh" 2>/dev/null; then
        echo "WARN: $overlay_dir/start.sh no longer reads CODEX_LINUX_NIX_LIBRARY_PATH; re-patch it (see home/codex-desktop.nix)" >&2
        export LD_LIBRARY_PATH="$nix_library_path''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      fi

      stop_stale_scopes
      if find_primary_scope >/dev/null 2>&1; then
        exec "$overlay_dir/start.sh" "$@"
      fi

      trap cleanup EXIT INT TERM HUP
      "$overlay_dir/start.sh" "$@" &
      launcher_pid=$!

      for _ in $(seq 1 100); do
        if owned_scope="$(find_primary_scope 2>/dev/null)"; then
          break
        fi
        kill -0 "$launcher_pid" 2>/dev/null || break
        sleep 0.05
      done

      if [ -n "$owned_scope" ]; then
        apply_scope_limits "$owned_scope" || \
          echo "WARN: could not apply Codex scope limits to $owned_scope" >&2
      else
        echo "WARN: could not identify the Codex application scope" >&2
      fi

      if wait "$launcher_pid"; then
        exit 0
      else
        exit $?
      fi
    '';
  };
in
lib.mkIf (config.home.username == "cjm") {
  home.packages = [ codexDesktopGuard ];

  home.file.".local/share/applications/codex-desktop.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=ChatGPT / Codex
      GenericName=AI coding assistant
      Comment=Chat with ChatGPT and work with Codex
      Exec=${codexDesktopGuard}/bin/codex-desktop-guard %U
      Icon=${overlayDir}/content/webview/assets/app-D0g8sCle.png
      Terminal=false
      Categories=Development;Utility;
      Keywords=ChatGPT;Codex;OpenAI;AI;Code;
      StartupNotify=true
      StartupWMClass=codex-desktop
      MimeType=x-scheme-handler/codex;x-scheme-handler/codex-browser-sidebar;
    '';
  };
}
