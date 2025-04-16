{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.amdgpu.stability;
  
  # Fetch the VCN reset patches
  vcnResetPatch1 = pkgs.fetchpatch {
    name = "amdgpu-vcn-reset-patch-1";
    url = "https://lore.kernel.org/amd-gfx/20250415145908.3790253-1-zaeem.mohamed@amd.com/raw";
    hash = lib.fakeSha256; # Replace with actual hash after first attempt
  };
  
  vcnResetPatch2 = pkgs.fetchpatch {
    name = "amdgpu-vcn-reset-patch-2";
    url = "https://lore.kernel.org/amd-gfx/20250415145908.3790253-2-zaeem.mohamed@amd.com/raw";
    hash = lib.fakeSha256; # Replace with actual hash after first attempt
  };
  
  # Create a patched amdgpu kernel module
  patchedAmdgpuModule = pkgs.callPackage ({ kernel }: 
    pkgs.stdenv.mkDerivation {
      name = "amdgpu-patched-${kernel.version}";
      
      buildCommand = ''
        mkdir -p $out
        ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/scripts/sign-file sha512 \
          ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/certs/signing_key.pem \
          ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/certs/signing_key.x509 \
          ${kernel}/lib/modules/${kernel.modDirVersion}/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko \
          $out/amdgpu.ko
      '';
      
      patches = [
        vcnResetPatch1
        vcnResetPatch2
      ];
    }
  ) { kernel = config.boot.kernelPackages.kernel; };

in {
  options.hardware.amdgpu.stability = {
    enable = mkEnableOption "AMD GPU stability patches for VCN reset issues";
  };

  config = mkIf cfg.enable {
    boot.extraModulePackages = [ patchedAmdgpuModule ];
    
    # Ensure the original amdgpu module doesn't load
    boot.blacklistedKernelModules = [ "amdgpu" ];
    
    # Load our patched module instead
    boot.kernelModules = [ "amdgpu" ];
  };
}