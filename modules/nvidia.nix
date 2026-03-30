{ config, lib, pkgs, ... }:

{
  # NVIDIA RTX 5070
  services.xserver.videoDrivers = [ "nvidia" ];

  # Early KMS + framebuffer — required for Ly, Plymouth, and proper console resolution
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Wayland + NVIDIA env vars
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GBM_BACKEND = "nvidia-drm";
    NVD_BACKEND = "direct";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # NVIDIA container toolkit — lets Docker containers use the GPU
  hardware.nvidia-container-toolkit.enable = true;
}
