{
  config,
  lib,
  pkgs,
  ...
}:

# webctx — SSH tunnel to the web-context gateway on the Mac mini.
#
# The gateway (Firecrawl + SearXNG + Playwright behind webctx-gateway) runs in
# Docker on `mini` and listens loopback-only at 127.0.0.1:8090 there; the MCP
# clients on this machine (Claude Code, Codex) are configured against
# http://127.0.0.1:18090/mcp. This unit keeps that forward alive over
# Tailscale SSH so webctx survives reboots on either end.
let
  homeDir = config.home.homeDirectory;
in
{
  systemd.user.services.webctx-tunnel = {
    Unit = {
      Description = "SSH tunnel to webctx gateway on mini (127.0.0.1:18090 -> mini:8090)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${homeDir}/.ssh/id_ed25519";
    };

    Service = {
      Type = "simple";
      # -N: no remote command; ExitOnForwardFailure + keepalives make ssh die
      # (and systemd restart it) whenever the forward or the link goes stale.
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.openssh}/bin/ssh"
        "-N"
        "-o ExitOnForwardFailure=yes"
        "-o ServerAliveInterval=30"
        "-o ServerAliveCountMax=3"
        "-o ConnectTimeout=10"
        "-o BatchMode=yes"
        "-o StrictHostKeyChecking=accept-new"
        "-L 127.0.0.1:18090:127.0.0.1:8090"
        "cjm@mini"
      ];
      Restart = "always";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
