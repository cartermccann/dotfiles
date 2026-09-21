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
in
{
  programs._1password = {
    enable = true;
    package = pkgs-unstable._1password-cli;
  };
  # 1Password ships its local MCP server inside the desktop app. The app only
  # accepts MCP connections from a peer whose effective GID is the dedicated
  # `onepassword-mcp` group ("Rejecting MCP connection: Linux peer effective
  # GID check failed" / "no application groups existed on the system"). The
  # upstream after-install.sh creates that group and makes the binary setgid
  # to it; the NixOS module only does this for 1Password-BrowserSupport.
  # A setgid wrapper in /run/wrappers/bin also puts `1password-mcp` on PATH,
  # which is the command MCP clients (Cursor, Claude Code, Codex) expect.
  # Read the package back off the module: programs._1password-gui applies a
  # polkitPolicyOwners override, so the raw attr would be a second full build.
  users.groups.onepassword-mcp = { };
  security.wrappers."1password-mcp" = {
    source = "${config.programs._1password-gui.package}/share/1password/1password-mcp";
    owner = "root";
    group = "onepassword-mcp";
    setuid = false;
    setgid = true;
  };

  programs._1password-gui = {
    enable = true;
    package = pkgs-unstable._1password-gui;
    polkitPolicyOwners = [ "cjm" ];
  };

  environment.systemPackages = with pkgs; [
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
