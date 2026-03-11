{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # NOTE: This is a placeholder. Run `nixos-generate-config --root /mnt`
  # during install and replace this file with the generated one.
  # The values below are based on your current Arch setup.

  boot.initrd.availableKernelModules = [
    "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  # Root — btrfs subvolume @
  fileSystems."/" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd:3" "ssd" "space_cache=v2" ];
  };

  # Home — btrfs subvolume @home (preserved from Arch)
  fileSystems."/home" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "ssd" "space_cache=v2" ];
  };

  # EFI boot partition
  fileSystems."/boot" = {
    device = "/dev/nvme0n1p1";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # zram swap
  zramSwap.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
}
