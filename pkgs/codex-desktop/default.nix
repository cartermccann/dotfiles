{ pkgs, upstream }:

# Keep local behavior reproducible across app updates. Upstream's optional
# features replace our old HID native-module and recursive-watcher patches.
(upstream.override {
  linuxFeatureIds = [
    "codex-micro"
    "computer-use-linux"
    "directory-only-working-tree-watch"
  ];
}).overrideAttrs
  (previous: {
    postInstall = (previous.postInstall or "") + ''
      ${pkgs.python3}/bin/python3 ${./patch-composer-dictation.py} \
        "$out/opt/codex-desktop/resources/app.asar" \
        "$out/opt/codex-desktop/.codex-linux/local-mods.json"
      # Voice and pets otherwise allocate a native canvas almost twice the
      # tallest display height, obstructing the desktop on Linux/Wayland.
      ${pkgs.python3}/bin/python3 ${./patch-overlay-bounds.py} \
        "$out/opt/codex-desktop/resources/app.asar" \
        "$out/opt/codex-desktop/.codex-linux/local-mods.json"
      # Upstream packs before patchelf. Refresh the native entry's size/digest
      # and Watchbound's manifest so its existing integrity checks remain valid.
      ${pkgs.python3}/bin/python3 ${./patch-watchbound-metadata.py} \
        "$out/opt/codex-desktop/resources/app.asar" \
        "$out/opt/codex-desktop/.codex-linux/local-mods.json"
      # Upstream reused its plugin version across backend changes. Both app
      # staging and installed-plugin caches compare versions, not binary bytes.
      ${pkgs.python3}/bin/python3 ${./version-computer-use.py} \
        "$out/opt/codex-desktop/resources/plugins/openai-bundled/plugins/computer-use" \
        "$out/opt/codex-desktop/.codex-linux/local-mods.json"
    '';
  })
