{
  config,
  lib,
  pkgs,
  ...
}:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  # Diagnostic: log BLE disconnect reason codes. btmon needs the privileged HCI
  # monitor socket, so it runs as a root system service. Correlate its timestamps
  # with micro-reconnect's "EVENT disconnected" logs to find WHY the Codex Micro
  # drops (0x13 = remote/device terminated, 0x08 = supervision timeout, 0x16 =
  # local). Read it with:  journalctl -u codex-bt-monitor -e
  # Safe to delete this block once the disconnect cause is known.
  systemd.services.codex-bt-monitor = {
    description = "BLE disconnect-reason logger (Codex Micro diagnostic)";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    serviceConfig = {
      # `unbuffer` runs btmon under a pseudo-terminal so it line-buffers its
      # output instead of block-buffering to the pipe (stdbuf can't fix btmon —
      # it doesn't use libc stdio buffering). Grep keeps the journal small.
      ExecStart = pkgs.writeShellScript "codex-bt-monitor" ''
        exec ${pkgs.expect}/bin/unbuffer ${pkgs.bluez}/bin/btmon -T \
          | ${pkgs.gnugrep}/bin/grep --line-buffered -A6 -iE "disconnect|reason:"
      '';
      Restart = "always";
      RestartSec = "5";
    };
  };

  environment.systemPackages = with pkgs; [
    bluetui # TUI bluetooth manager
  ];
}
