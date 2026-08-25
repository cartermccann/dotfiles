{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  zen-browser,
  helium,
  claude-desktop,
  ...
}:

let
  waylandFlags = [
    "--ozone-platform-hint=auto"
    "--enable-features=TouchpadOverscrollHistoryNavigation,WebRTCPipeWireCapturer"
  ];

  googleChromeWrapped = pkgs.google-chrome.override {
    commandLineArgs = waylandFlags ++ [
      "--disable-accelerated-video-decode"
      "--disable-gpu-video-decoder"
      "--oauth2-client-id=77185425430.apps.googleusercontent.com"
      "--oauth2-client-secret=OTJgUOQcT7lO7GsGZq2G4IlT"
    ];
  };
  # 1Password ships its local MCP server inside the desktop app, but the module
  # doesn't put it on PATH. MCP clients expect a plain `1password-mcp` command.
  # Read the package back off the module rather than using the raw unstable
  # attr: programs._1password-gui applies a polkitPolicyOwners override, so the
  # raw attr is a *different* derivation and pulling it in would put a second
  # full 1Password build in the closure.
  onePasswordMcp = pkgs.writeShellScriptBin "1password-mcp" ''
    exec ${config.programs._1password-gui.package}/share/1password/1password-mcp "$@"
  '';
in
{
  programs._1password = {
    enable = true;
    package = pkgs-unstable._1password-cli;
  };
  programs._1password-gui = {
    enable = true;
    package = pkgs-unstable._1password-gui;
    polkitPolicyOwners = [ "cjm" ];
  };

  environment.systemPackages = with pkgs; [
    onePasswordMcp

    # Browsers
    googleChromeWrapped
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    floorp-bin
    helium.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Communication
    slack
    pkgs-unstable.beeper

    # Utilities
    localsend # local file sharing
    nautilus # file manager
    gnome-disk-utility
    gnome-calculator
    fastfetch
    inxi
    blanket
    statix # nix linter

    #Graphic editor
    inkscape
    lsd
    # Notes
    obsidian

    #code editor
    # pinned ahead of nixpkgs code-cursor; vscode-generic isn't a top-level
    # attr, nixpkgs passes it as a path at each call site too
    (callPackage ../pkgs/code-cursor {
      vscode-generic = "${pkgs.path}/pkgs/applications/editors/vscode/generic.nix";
    })
    cursor-cli
    # AI
    claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs
  ];
}
