{
  config,
  pkgs,
  ...
}:

let
  mountPoint = "${config.home.homeDirectory}/GoogleDrive";
in
{
  home.packages = with pkgs; [
    rclone
  ];

  systemd.user.services.rclone-google-drive = {
    Unit = {
      Description = "Rclone Google Drive mount";
      Documentation = [ "man:rclone(1)" ];
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
    };

    Service = {
      Type = "simple";
      # NixOS provides the setuid fusermount helper via /run/wrappers/bin.
      # Without this PATH, rclone may find a non-setuid store helper and fail with:
      # "fusermount3: mount failed: Operation not permitted".
      Environment = "PATH=/run/wrappers/bin:${pkgs.fuse3}/bin:${pkgs.coreutils}/bin";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount gdrive: ${mountPoint} \
          --vfs-cache-mode writes \
          --dir-cache-time 1h \
          --poll-interval 1m \
          --umask 002
      '';
      ExecStop = "/run/wrappers/bin/fusermount3 -u ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
