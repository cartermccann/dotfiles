{ config, lib, pkgs, ... }:

{
  # Snapper for btrfs snapshots
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs = {
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ "cjm" "carter" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 5;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 6;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    snapper
  ];
}
