{
  config,
  lib,
  pkgs,
  ...
}:

{
  # NVIDIA RTX 5070
  services.xserver.videoDrivers = [ "nvidia" ];

  # Early KMS + framebuffer — required for Ly, Plymouth, and proper console resolution
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  # These video= modes are the CONSOLE geometry only — the Ly greeter and any
  # VT. Both compositors name their modes explicitly (home/hyprland/
  # compositor.nix, home/niri-noctalia.nix), so the desktop still runs the HP
  # at its native 2560x1440 and this cannot leak into a session.
  #
  # HDMI-A-1 is deliberately NOT at its native 2560x1440 here. There is one
  # framebuffer for both outputs, and drm_fb_helper sizes it asymmetrically:
  # surface_width/height take the MAX of the connected modes
  # (drm_fb_helper.c:1590) while fb_width/height, the area fbcon is allowed to
  # draw in, take the MIN (:1609). With the HP at 2560x1440 and the Dell at
  # 1920x1080 that yielded a 2560x1440 allocation with a 1920x1072 console
  # (`Console: switching to colour frame buffer device 240x67`) — i.e. the
  # greeter pinned to the top-left of the HP with a 640px black bar down the
  # right and 368px along the bottom. Matching the modes makes min == max, so
  # the console fills the framebuffer and the HP scales 1080p to its panel.
  # The cost is slightly soft console text on the HP; the alternative is the
  # bars.
  #
  # And no, the vertical Dell cannot be un-rotated here. fbcon has a single
  # rotation for the whole framebuffer and "cannot handle separate rotation
  # settings per output" (drm_fb_helper.c:1826) — mixed requests fall back to
  # unrotated. Pushing it into hardware instead does not work either:
  # drm_client_rotation() refuses anything that is not 0 or 180 degrees
  # outright, before it ever looks at what the driver supports
  # (drm_client_modeset.c, "TODO: support 90 / 270 degree hardware rotation").
  # So `video=DP-1:...,rotate=270` parses fine and then does nothing. Portrait
  # on the Dell is only available by rotating the HP too, which is a worse
  # trade. A greeter that gets both panels right has to be a Wayland one.
  #
  # Nor can the Dell simply be left dark at the greeter so only the HP shows
  # it. The modes match, so drm_client_modeset clones one framebuffer to both
  # connectors and Ly lands on each. Suppressing one means forcing that
  # connector off (`video=DP-1:d`), and DRM_FORCE_OFF is not scoped to the
  # console: drm_helper_probe_single_connector_modes short-circuits detect and
  # pins connector->status to disconnected for every client, so Hyprland would
  # stop seeing the Dell as well. Sideways at the greeter is the price of the
  # panel being portrait in the session.
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "video=DP-1:1920x1080@60"
    "video=HDMI-A-1:1920x1080@60"
  ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Required for S3 to be survivable. The driver frees video memory across
    # suspend unless told not to, so on resume the compositor's GL objects
    # point at allocations that no longer exist. What that looked like here
    # (journal, 2026-08-09 18:10, ~12 min suspend):
    #
    #   NVRM: Xid 13, name=.Hyprland-wrapp, Graphics Exception:
    #         Shader Program Header 11 Error / ESR 0x405840=0xa2040800
    #   [nvidia-drm] Failed to initialize semaphore for plane fence
    #   [nvidia-drm] Failed to apply atomic modeset. Error code: -11
    #   Hyprland has crashed :(   (SIGABRT in CHyprOpenGLImpl::begin)
    #
    # i.e. the session does not "come back wrong", it is already dead — which
    # is why the leftover screen takes no input and only a reboot clears it.
    #
    # Enabling this adds NVreg_PreserveVideoMemoryAllocations=1 plus the
    # nvidia-{suspend,resume,hibernate} units, which save VRAM to
    # NVreg_TemporaryFilePath (default /tmp, disk-backed on this host — worth
    # rechecking if /tmp is ever moved to tmpfs, since the dump is sized by
    # what the GPU has allocated) and restore it before userspace resumes.
    powerManagement.enable = true;
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
