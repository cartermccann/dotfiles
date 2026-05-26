{
  config,
  lib,
  pkgs,
  ...
}:

{
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    algorithm = "zstd";
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeMemKillThreshold = 3;
    freeSwapThreshold = 10;
    freeSwapKillThreshold = 5;
    extraArgs = [
      "--prefer"
      "^(2\\.1\\.150|claude|node|bfs|chromium|chrome|firefox|zen|ffmpeg|HandBrake)$"
      "--avoid"
      "^(systemd|systemd-.*|niri|Xwayland|wireplumber|pipewire|pipewire-pulse|sshd|dbus-daemon|gnome-keyring|gpg-agent)$"
    ];
  };

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableRootSlice = true;
    enableSystemSlice = false;
  };
}
