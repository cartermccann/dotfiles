{
  config,
  lib,
  pkgs,
  qmd,
  ...
}:

# brain: Jev-augmented search over the QMD corpus (~/projects/Personal/brain).
# Runs from the project's uv virtualenv on purpose: typesafe-sdk and its
# dependency chain are not in nixpkgs, and this is a personal tool that
# changes weekly. `uv sync` in the project dir is the install step.
# brain-tag.service is triggered by qmd-index-update.service (OnSuccess).
let
  qmdPackage = import ../pkgs/qmd-nixos { inherit pkgs qmd; };
  projectDir = "${config.home.homeDirectory}/projects/Personal/brain";
  brainBin = "${projectDir}/.venv/bin/brain";
in
lib.mkIf (config.home.username == "cjm") {
  # `brain` on PATH without polluting the store: a tiny wrapper to the venv.
  home.packages = [
    (pkgs.writeShellScriptBin "brain" ''
      export PATH="${qmdPackage}/bin:$PATH"
      exec "${brainBin}" "$@"
    '')
  ];

  systemd.user.services.brain-tag = {
    Unit = {
      Description = "Tag new QMD documents with Jev (brain phase 2)";
      # Skip cleanly if the project venv is not built yet.
      ConditionPathExists = brainBin;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${brainBin} tag --workers 8";
      EnvironmentFile = "${config.home.homeDirectory}/.config/credentials/typesafe.env";
      Environment = [ "PATH=${qmdPackage}/bin:${pkgs.coreutils}/bin" ];
      TimeoutStartSec = 3600;
      Nice = 10;
      CPUQuota = "100%";
      IOSchedulingClass = "idle";
    };
  };
}
