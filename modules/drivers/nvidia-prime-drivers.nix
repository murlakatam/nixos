{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.nvidia-prime;
in {
  options.drivers.nvidia-prime = {
    enable = mkEnableOption "Enable Nvidia Prime Hybrid GPU Offload";
    amdgpuBusId = mkOption {
      type = types.str;
      #default = "PCI:101:0:0";
      default = "PCI:101@0:0:0";
    };
    nvidiaBusID = mkOption {
      type = types.str;
      #default = "PCI:100:0:0";
      default = "PCI:100@0:0:0";
    };
  };

  # This is all you need!
  config = mkIf cfg.enable {
    hardware.nvidia.prime = {
      offload = {
        enable = true;
        # This provides the `nvidia-offload` command for you.
        enableOffloadCmd = true;
      };
      amdgpuBusId = cfg.amdgpuBusId;
      nvidiaBusId = cfg.nvidiaBusID;
    };
  };
}
