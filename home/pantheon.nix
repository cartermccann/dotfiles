# Pantheon AI stack — Home Manager configuration
# MCP servers, tools, and extras for the full profile

{ config, lib, pkgs, ... }:

{
  pantheon = {
    profile = "full";

    mcp.servers = {
      context7.enable = true;
      github = {
        enable = true;
        secretsFile = "~/.config/pantheon/secrets/github.env";
      };
      playwright.enable = true;
      nixos-mcp.enable = true;
      gws.enable = true;
      # Slack: using existing xoxc/xoxd tokens from ~/.mcp.json for now
      # Enable this once you have xoxb/xapp bot tokens from api.slack.com/apps
      slack.enable = false;
    };
  };
}
