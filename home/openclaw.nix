{ config, pkgs, lib, user, ... }:

let
  openclawVersion = "2026.3.8";
  npmGlobalDir = "$HOME/.npm-global";

  baseConfig = ./openclaw/config.json;
  secretsExample = ./openclaw/secrets.json.example;

  # Merge base config with local secrets and resolve placeholders
  mergeScript = pkgs.writeShellScript "openclaw-merge-config" ''
    set -euo pipefail
    OPENCLAW_DIR="$HOME/.openclaw"
    BASE_CONFIG="${baseConfig}"
    SECRETS_FILE="$OPENCLAW_DIR/secrets.json"
    OUTPUT="$OPENCLAW_DIR/openclaw.json"

    mkdir -p "$OPENCLAW_DIR"

    # Start from base config, replacing home directory placeholder
    ${pkgs.jq}/bin/jq --arg home "$HOME" '
      walk(if type == "string" then gsub("PLACEHOLDER_HOME"; $home) else . end)
    ' "$BASE_CONFIG" > "$OUTPUT.tmp"

    # Merge secrets if they exist
    if [ -f "$SECRETS_FILE" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$OUTPUT.tmp" "$SECRETS_FILE" > "$OUTPUT"
      rm "$OUTPUT.tmp"
    else
      mv "$OUTPUT.tmp" "$OUTPUT"
      echo "openclaw: WARNING — no secrets.json found at $SECRETS_FILE"
      echo "  cp ~/.openclaw/secrets.json.example $SECRETS_FILE"
    fi

    chmod 600 "$OUTPUT"
  '';

  # Install/update openclaw via npm with version pinning
  installScript = pkgs.writeShellScript "openclaw-install" ''
    set -euo pipefail
    export PATH="${pkgs.nodejs}/bin:${pkgs.git}/bin:$PATH"
    export npm_config_prefix="${npmGlobalDir}"

    WANTED="${openclawVersion}"
    CURRENT=$(${npmGlobalDir}/bin/openclaw --version 2>/dev/null || echo "none")

    if [ "$CURRENT" != "$WANTED" ]; then
      echo "openclaw: installing $WANTED (current: $CURRENT)"
      npm install -g "openclaw@$WANTED" --loglevel=warn
    fi
  '';
in
{
  # Add npm global bin to PATH via home-manager (no shell hacks needed)
  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  # Openclaw environment variables
  home.sessionVariables = {
    NODE_COMPILE_CACHE = "/var/tmp/openclaw-compile-cache";
    OPENCLAW_NO_RESPAWN = "1";
  };

  # Deploy the secrets example for reference
  home.file.".openclaw/secrets.json.example".source = secretsExample;

  # Install openclaw + merge config on activation
  home.activation.openclawInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${installScript}
  '';
  home.activation.openclawConfig = lib.hm.dag.entryAfter [ "openclawInstall" ] ''
    run ${mergeScript}
  '';

  # Systemd user service for openclaw gateway
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw Gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "%h/.npm-global/bin/openclaw gateway --port 18789";
      Restart = "always";
      RestartSec = 5;
      KillMode = "process";
      Environment = [
        "PATH=%h/.npm-global/bin:${pkgs.nodejs}/bin:/run/current-system/sw/bin:/usr/bin:/bin"
        "NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache"
        "OPENCLAW_NO_RESPAWN=1"
        "OPENCLAW_GATEWAY_PORT=18789"
        "OPENCLAW_SERVICE_MARKER=openclaw"
        "OPENCLAW_SERVICE_KIND=gateway"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
