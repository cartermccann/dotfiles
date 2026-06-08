{
  config,
  lib,
  pkgs,
  ...
}:

# Headroom — the context-optimization proxy for LLM agents.
#
# Headroom itself is installed imperatively as a uv tool (`uv tool install
# "headroom-ai[all]"`, binary at ~/.local/bin/headroom). It self-manages its
# venv, ONNX models (cached under ~/.cache/huggingface) and config, so we do
# NOT package it as a derivation — we just keep its proxy running and expose
# opt-in shell wrappers that route agents through it.
#
# The proxy sits between Claude Code / Codex and the upstream API, auto-
# compressing large tool outputs (file listings, search results, big reads)
# for a 60-95% token reduction. Agents only route through it when launched via
# the `hclaude` / `hcodex` wrappers below — plain `claude` / `codex` stay direct.
let
  homeDir = config.home.homeDirectory;
  headroom = "${homeDir}/.local/bin/headroom";
  proxyUrl = "http://127.0.0.1:8787";
in
{
  systemd.user.services.headroom-proxy = {
    Unit = {
      Description = "Headroom context-optimization proxy";
      Documentation = [ "https://github.com/chopratejas/headroom" ];
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # The uv-tool binary must exist; skip cleanly if Headroom was uninstalled.
      ConditionPathExists = headroom;
    };

    Service = {
      Type = "simple";
      # NixOS doesn't put libstdc++ on a standard search path, but the proxy's
      # Python deps (numpy / onnxruntime) dlopen it at runtime. Provide it
      # explicitly — same fix the source build needed.
      Environment = [
        "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        "PATH=${homeDir}/.local/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
      # token mode = maximum compression of tool outputs.
      # --no-telemetry: opt out of Headroom's anonymous aggregate stats.
      ExecStart = "${headroom} proxy --mode token --no-telemetry";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Opt-in wrappers: route a single agent launch through the proxy without
  # touching the bare `claude` / `codex` commands. Named `hclaude` / `hcodex`
  # to avoid shadowing the C compiler (`cc`) and other binaries on PATH.
  programs.fish.functions = {
    hclaude = {
      description = "Launch Claude Code through the Headroom proxy";
      body = "env ANTHROPIC_BASE_URL=${proxyUrl} claude $argv";
    };
    hcodex = {
      description = "Launch Codex through the Headroom proxy";
      body = "env OPENAI_BASE_URL=${proxyUrl}/v1 codex $argv";
    };
    hrstats = {
      description = "Show Headroom proxy health + compression stats";
      body = ''
        if not curl -sf ${proxyUrl}/health >/dev/null 2>&1
            echo "Headroom proxy not reachable on ${proxyUrl}"
            echo "Check it with: systemctl --user status headroom-proxy"
            return 1
        end
        curl -s ${proxyUrl}/stats | ${pkgs.jq}/bin/jq .
      '';
    };
  };
}
