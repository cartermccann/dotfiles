{
  config,
  lib,
  pkgs,
  qmd,
  ...
}:

# QMD: local hybrid (lexical + embedding) search over Carter's document corpus
# (Obsidian vault, ~/projects, ~/Documents). Collections are declared in
# config/qmd/index.yml; the timers below keep the index fresh.
let
  qmdPackage = import ../pkgs/qmd-nixos { inherit pkgs qmd; };
in
lib.mkIf (config.home.username == "cjm") {
  home.packages = [ qmdPackage ];

  # Keep the collection manifest writable and versioned: qmd's own collection
  # commands can update it, and the resulting change remains visible in git.
  xdg.configFile."qmd/index.yml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/config/qmd/index.yml";
    force = true;
  };

  systemd.user.services = {
    qmd-index-update = {
      Unit.Description = "Refresh Carter's QMD document index";
      Service = {
        Type = "oneshot";
        ExecStart = "${qmdPackage}/bin/qmd update";
        TimeoutStartSec = 1800;
      };
    };

    qmd-index-embed = {
      Unit.Description = "Refresh QMD embeddings and reranking index";
      Service = {
        Type = "oneshot";
        ExecStart = "${qmdPackage}/bin/qmd embed";
        TimeoutStartSec = 14400;
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
  };

  systemd.user.timers = {
    qmd-index-update = {
      Unit.Description = "Refresh QMD lexical index every 30 minutes";
      Timer = {
        OnCalendar = "*-*-* *:00/30:00";
        Persistent = true;
        Unit = "qmd-index-update.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    qmd-index-embed = {
      Unit.Description = "Refresh QMD embeddings weekly";
      Timer = {
        OnCalendar = "Sun *-*-* 03:15:00";
        Persistent = true;
        RandomizedDelaySec = "20m";
        Unit = "qmd-index-embed.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
