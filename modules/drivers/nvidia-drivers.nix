{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.drivers.nvidia;
in {
  options.drivers.nvidia = {
    enable = mkEnableOption "Enable Nvidia Drivers";
  };

  config = mkMerge [
    # Configuration when NVIDIA is enabled
    (mkIf cfg.enable {
      # Enable OpenGL
      hardware.graphics = {
        enable = true;
      };

      # Load nvidia driver for Xorg and Wayland
      services.xserver.videoDrivers = ["nvidia"];

      # sleep kernel params
      boot.kernelParams = [
        # REMOVED "mem_sleep_default=deep" because it causes crashes on modern laptops (s2idle is better)
        "nvidia.NVreg_EnableS0ixPowerManagement=1"
        #"nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Helps save VRAM state
      ];

      hardware.nvidia = {
        # Modesetting is required. (Wayland/Hyperland requires kernel mode setting (KMS) to be enabled (Highly Recommended))
        modesetting.enable = true;

        # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
        # Enable this if you have graphical corruption issues or application crashes after waking
        # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
        # of just the bare essentials.
        powerManagement.enable = true;

        # Fine-grained power management. Turns off GPU when not in use.
        # Experimental and only works on modern Nvidia GPUs (Turing or newer).
        powerManagement.finegrained = true;

        # Use the NVidia open source kernel module (not to be confused with the
        # independent third-party "nouveau" open source driver).
        # Support is limited to the Turing and later architectures. Full list of
        # supported GPUs is at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
        # Only available from driver 515.43.04+
        # An important note to take is that the option hardware.nvidia.open
        # should only be set to false if you have a GPU with an older architecture than Turing (older than the RTX 20-Series).
        # For newer cards it is recommended by NVIDIA to use the open Drivers:
        # https://download.nvidia.com/XFree86/Linux-x86_64/565.77/README/kernel_open.html
        # So If you have an GPU with Turing architecture (RTX 20-Series) or newer set hardware.nvidia.open to true
        open = true;

        # Enable the Nvidia settings menu,
        # accessible via `nvidia-settings`.
        nvidiaSettings = true;

        # Optionally, you may need to select the appropriate driver version for your specific GPU.
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };

      virtualisation.docker.enableNvidia = true;

      # Stolen from https://wiki.nixos.org/wiki/NVIDIA#Troubleshooting

      # https://discourse.nixos.org/t/black-screen-after-suspend-hibernate-with-nvidia/54341/6
      # https://discourse.nixos.org/t/suspend-problem/54033/28
      systemd = {
        # Uncertain if this is still required or not.
        services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

        services."gnome-suspend" = {
          description = "suspend gnome shell";
          before = [
            "systemd-suspend.service"
            "systemd-hibernate.service"
            "nvidia-suspend.service"
            "nvidia-hibernate.service"
          ];
          wantedBy = [
            "systemd-suspend.service"
            "systemd-hibernate.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = ''${pkgs.procps}/bin/pkill -f -STOP ${pkgs.gnome-shell}/bin/gnome-shell'';
          };
        };
        services."gnome-resume" = {
          description = "resume gnome shell";
          after = [
            "systemd-suspend.service"
            "systemd-hibernate.service"
            "nvidia-resume.service"
          ];
          wantedBy = [
            "systemd-suspend.service"
            "systemd-hibernate.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = ''${pkgs.procps}/bin/pkill -f -CONT ${pkgs.gnome-shell}/bin/gnome-shell'';
          };
        };
      };
    })

    # Configuration when NVIDIA is disabled
    (mkIf (!cfg.enable) {
      boot.extraModprobeConfig = ''
        blacklist nouveau
        options nouveau modeset=0
      '';

      services.udev.extraRules = ''
        # Remove NVIDIA USB xHCI Host Controller devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA USB Type-C UCSI devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA Audio devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA VGA/3D controller devices
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
      '';
    })
  ];
}
