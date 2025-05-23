{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.amdgpu;
in {
  options.drivers.amdgpu = {
    enable = mkEnableOption "Enable AMD Drivers (GPU and CPU)";
    stability = {
      enablePatches = mkEnableOption "Enable stability patches for AMD GPU VCN reset issues";
    };
  };

  config = mkIf cfg.enable {
    # Systemd tmpfiles rules for ROCm HIP (ollama shite)
    #systemd.tmpfiles.rules = ["L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"];

    # Enable the stability patches if requested
    hardware.amdgpu.stability.enable = cfg.stability.enablePatches;

    # Video drivers configuration for X server
    services.xserver.videoDrivers = ["amdgpu"];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          amdvlk
        ];
        #For 32 bit applications
        extraPackages32 = with pkgs; [
          driversi686Linux.amdvlk
        ];
      };

      # CPU microcode updates
      cpu.amd.updateMicrocode = true;
    };

    # Boot configuration for AMD GPU support
    boot = {
      initrd.kernelModules = [];
      kernelModules = ["kvm-amd" "amdgpu" "v4l2loopback" "amd_pstate"];
      kernelParams = [
        "amd_pstate=active"
        "processor.max_cstate=1"
        "amdgpu.aspm=0"
        "amdgpu.runpm=0"
        "amdgpu.bapm=0"
        "tsc=unstable"
        "radeon.si_support=0"
        "amdgpu.si_support=1"
        "amdgpu.dcdebugmask=0x412" #try 0x12 if doesn't work, and then 0x412
        "amdgpu.lockup_timeout=100000"
        #For your external DisplayPort monitor
        #"video=DP-2:3840x2560@60"
        #For your built-in laptop display
        #"video=eDP-1:3840x2400@60"
      ];
      extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
      #blacklistedKernelModules = ["radeon"];
    };
  };
}
