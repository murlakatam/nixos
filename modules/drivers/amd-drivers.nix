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
  };

  config = mkIf cfg.enable {
    # Systemd tmpfiles rules for ROCm HIP (ollama shite)
    #systemd.tmpfiles.rules = ["L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"];

    # Video drivers configuration for X server
    # services.xserver.videoDrivers = ["amdgpu"];

    hardware = {
      #  graphics = {
      #    enable = true;
      #enable32Bit = true;
      #extraPackages = with pkgs; [
      #  amdvlk
      #];
      # For 32 bit applications
      #extraPackages32 = with pkgs; [
      #  driversi686Linux.amdvlk
      #];
      #  };

      # CPU microcode updates
      cpu.amd.updateMicrocode = true;
    };

    # Boot configuration for AMD GPU support
    boot = {
      initrd.kernelModules = [];
      kernelModules = ["kvm-amd"]; # "v4l2loopback"];
      #kernelParams = [
      #"amd_pstate=active"
      #"tsc=unstable"
      #"radeon.si_support=0"
      #"amdgpu.si_support=1"
      #"amdgpu.dcdebugmask=0x10" #try 0x12 if doesn't work, and then 0x412
      #"amdgpu.lockup_timeout=100000"
      # For your external DisplayPort monitor
      #"video=DP-2:3840x2560@60"
      # For your built-in laptop display
      #"video=eDP-1:3840x2400@60"
      #];
      #extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
      #blacklistedKernelModules = ["radeon"];
    };

    environment.systemPackages = with pkgs; [lact];
    systemd.packages = with pkgs; [lact];
    systemd.services.lactd.wantedBy = ["multi-user.target"];
  };
}
