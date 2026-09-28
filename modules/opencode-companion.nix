{
  config,
  pkgs,
  user,
  ...
}:

let
  home = config.users.users.${user}.home;
  state = "${home}/.local/share/opencode-companion";
  passwordFile = "${home}/.config/opencode-companion/password";
  # The Android candidate admits exactly 1.18.32. Do not use the separately
  # installed interactive OpenCode package or silently upgrade this server.
  server = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-companion-server";
    version = "1.18.32";
    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v1.18.32/opencode-linux-x64.tar.gz";
      hash = "sha256-MEbgQE/cYPuAMH56R4JLoHR3NkF4pNCbqoVISW3W1Ds=";
    };
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      echo '513f500a1a5ea1dc7d865547ac87b32a8936334e8d5abd5b3ff585c45a170080  opencode' | sha256sum --check
      install -Dm755 opencode "$out/bin/opencode"
      runHook postInstall
    '';
    # Keep the verified upstream binary intact; nix-ld supplies its interpreter.
    dontFixup = true;
    meta.platforms = [ "x86_64-linux" ];
  };
  launcher = pkgs.writeShellScript "opencode-companion" ''
    exec ${pkgs.python3}/bin/python3 ${../scripts/opencode-companion.py} \
      ${pkgs.bubblewrap}/bin/bwrap ${server}/bin/opencode \
      ${state} ${passwordFile}
  '';
in
{
  assertions = [
    {
      assertion = config.programs.nix-ld.enable;
      message = "The pinned OpenCode companion server requires nix-ld.";
    }
  ];

  # System scope starts before desktop login. Mutable state and the existing
  # password must be migrated first; neither is ever placed in the Nix store.
  systemd.services.opencode-companion = {
    description = "Private OpenCode companion development server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "podman-ollama.service"
    ];
    wants = [ "podman-ollama.service" ];
    unitConfig.RequiresMountsFor = [
      state
      passwordFile
    ];
    serviceConfig = {
      User = user;
      ExecStart = launcher;
      Restart = "always";
      RestartSec = 5;
      TimeoutStopSec = 20;
      KillMode = "control-group";
      UMask = "0077";
      NoNewPrivileges = true;
      LimitCORE = 0;
      StandardOutput = "null";
      StandardError = "journal";
    };
  };
}
