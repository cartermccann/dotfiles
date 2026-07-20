{
  config,
  lib,
  pkgs,
  ...
}:

# Vault-brain sync — keeps the cognee knowledge-graph index at
# ~/projects/Personal/vault-cognee-bridge current with the Obsidian LLM Wiki
# (~/Documents/ObsidianVaults/OBSIDIAN2).
#
# The bridge is the ONLY writer to the index (single-writer invariant from the
# shared-memory sidecar design doc in the vault). Each run: hash-diff the
# vault's Meeting Notes + Hermes Sessions, batch new/changed files through
# `codex exec` (KG extraction, billed to the ChatGPT sub), load via cognee's
# low-level API with local nomic embeddings (ollama, loopback). No API keys,
# no paid tokens, nothing leaves the box except the Codex-lane extraction.
#
# The project itself (uv venv, scripts, state) is imperative by design — like
# headroom, it self-manages; we only schedule it.
let
  homeDir = config.home.homeDirectory;
  bridgeDir = "${homeDir}/projects/Personal/vault-cognee-bridge";
in
{
  systemd.user.services.vault-brain-sync = {
    Unit = {
      Description = "Sync Obsidian vault into the cognee knowledge graph (Codex lane)";
      # Skip cleanly if the bridge project or Codex auth is missing.
      ConditionPathExists = [
        "${bridgeDir}/drive_codex.py"
        "${homeDir}/.codex/auth.json"
      ];
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      WorkingDirectory = bridgeDir;
      # codex lives in the home-manager per-user profile, not the system path.
      # LD_LIBRARY_PATH: native wheels (tokenizers/onnx) dlopen libstdc++,
      # which NixOS keeps off the default search path; nix-ld's lib dir is a
      # rebuild-stable location for it (same quirk headroom pins per-store-path).
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:${homeDir}/.local/bin:${homeDir}/.npm-global/bin:/run/current-system/sw/bin"
        "LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib"
      ];
      ExecStart = "${pkgs.uv}/bin/uv run python ${bridgeDir}/drive_codex.py";
      # A full first-run backfill can be long; steady-state runs are minutes.
      TimeoutStartSec = "2h";
    };
  };

  systemd.user.timers.vault-brain-sync = {
    Unit.Description = "Vault-brain sync: twice daily (raise cadence once quota impact is known)";
    Timer = {
      # 06:30 catches overnight Hermes sessions before the workday; 18:30
      # catches the day's meetings. Session files land hourly, so raise toward
      # "*-*-* 06,12,18:00:00" if fresher recall proves worth the Codex quota.
      OnCalendar = "*-*-* 06,18:30:00";
      # Catch up after downtime instead of silently skipping a window.
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
