# Codex desktop on kronos

The desktop entry is configured in `home/codex-desktop.nix`. It uses the
`codex-desktop-linux` flake input, wrapped by `pkgs/codex-desktop/default.nix`.
The input retains its own nixpkgs because its native runtime needs that exact
library set. All application libraries are now dependencies of the Nix package.

The September 4, 2026 update uses official Linux app **26.901.31953**, verified
against OpenAI's signed stable APT metadata, through community source revision
`23c55eb49ca724e8b7a1e698c1f3df075be42631`.

## Preserved behavior

- `codex-micro`: Linux USB/Bluetooth native bindings, feature visibility and
  hotplug support. Existing system udev rules remain in `modules/common.nix`.
- `directory-only-working-tree-watch`: bounded recursive watches with Git
  ignore handling, replacing the old custom `__cjmRecursiveWatch` preamble.
- Composer dictation: local gate override `4100906017`, retaining upstream
  microphone availability, loading and ChatGPT authentication checks.
- System dictation scripts and Micro bridge services remain independently
  configured by their existing Home Manager modules.
- Native `~/.config/Codex` profile and `~/.codex` agent data; explicit user
  overrides remain supported. No profile migration is needed.
- `codex-desktop` window class, URI forwarding, and scope limits of 28 GiB
  MemoryHigh, 32 GiB MemoryMax and 8,000 tasks. Existing environment overrides
  for those limits are honored. Each invocation cleans only its own exited
  application's scope.

The wrapper refuses to start while the legacy overlay's primary process is
running. Community launch usage reporting defaults off.

## Computer use and conversational voice

`computer-use-linux` enables the community Linux backend and app UI. Official
Linux Computer Use is not yet supported by OpenAI. The backend uses Hyprland
window targeting, the screenshot portal, AT-SPI, and the existing ydotoold
socket at `/run/ydotoold/socket`. The launcher exports that socket path while
honoring an explicit `YDOTOOL_SOCKET` override. No new uinput permissions are
needed. This controls the shared desktop; it is not a separate virtual desktop.
The packaged plugin version includes a backend content hash: upstream reused
its version across binary changes, and the app otherwise retains stale staging
and installed-plugin caches. Restart reconciles the changed version normally.

After switching and reopening the app, check Plugins > Computer Use and start
with "Check whether Linux Computer Use is ready". The plugin was already enabled
in Carter's Codex configuration. Keep initial trials confined to a disposable
test window.

Conversational ChatGPT Voice is separate from composer dictation. Settings >
Voice > Voice chat contains persistent controls; Start new voice chat resumes
the microphone/voice setup. The introductory banner records itself as seen when
setup opens, even before completion. Voice availability still depends on account
and workspace access. Screen context is a macOS-only extra in this release.

### Voice and pet overlay bounds

The shared avatar/voice overlay's native-draw layout allocates a canvas almost
twice the tallest display's height. On kronos, a 1,920-pixel portrait display
and an 87-pixel mascot produce `2 * 1920 + 56 - 87 = 3809` pixels, matching the
observed oversized voice window. The window is non-resizable; a compositor
resize did not hold. This is app geometry, not a Caelestia size rule.

The local Linux fix selects the existing compact viewport branch after the
native tray and placement calculations. That branch recomputes the mascot and
control offsets for its bounds instead of cropping the large canvas afterward.
Other platforms retain their existing native-canvas branch. The change is
applied during the Nix build, not to the running application's archive.

After activation and app restart, verify a voice call followed by navigation
to another task: the overlay should remain compact, its mute/end controls
should work, and other apps should remain usable. Check pet appearance and
expanded tray/captions as well. A successful build does not establish these
live interaction results.

## Updating and checking

Update the explicit community revision in `flake.nix`, refresh only that flake
input, and verify its pinned Linux package still matches signed stable metadata
using the upstream `scripts/ci/update-nix-hashes.sh check` command. The upstream
README currently names an older, missing script for this operation.

Run local patch tests, then `nh os build ~/dotfiles`. Apply with `nrs` from a
normal terminal; a privileged switch requires Carter's sudo password. Quit the
existing app and reopen the desktop entry after activation. Actual dictation
and hardware key actions should be checked in the newly opened app.

The local ASAR patches reject unknown bundle shapes rather than silently lose
the modifications. The Watchbound repair updates native-module metadata after
Nix's ELF patching; the loader's size and SHA-256 checks remain enabled.

For a non-launching diagnostic, invoke the package's
`opt/codex-desktop/start.sh --diagnose` directly. The upstream `bin/codex-desktop`
wrapper can prepend Wayland flags ahead of `--diagnose`, accidentally launching
the GUI instead.

## Rollback

The previous overlay remains at
`~/projects/input-linux/codex-desktop-overlay/`. Its files were not replaced.
`~/projects/input-linux/codex-update-20260904/` contains the prior configuration
snapshots, signed-release evidence, and a GC root for the previous system.
The snapshots include pre-existing local work; do not blindly restore entire
files over newer edits. Use the previous NixOS generation or restore only the
Codex-specific configuration changes, then rebuild and switch.

The update does not commit, reset or otherwise discard unrelated dotfiles work.
