{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.hardware.amdgpu.stability;
in {
  options.hardware.amdgpu.stability = {
    enable = mkEnableOption "AMD GPU stability patches for VCN reset issues";
  };

  config = mkIf cfg.enable {
    # Apply the hardcoded patches from local files
    boot.kernelPatches = [
      {
        name = "amdgpu-vcn-reset-fix-1";
        patch = ./amdgpu-vcn-reset-fix-1.patch;
      }
      {
        name = "amdgpu-vcn-reset-fix-2";
        patch = ./amdgpu-vcn-reset-fix-2.patch;
      }
    ];
  };
}
