{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.drivers.asus-backlight;
in {
  options.drivers.asus-backlight = {
    enable = mkEnableOption "Enable Asus Nvidia Keyboard Backlight";
  };

  config = mkMerge [
    # Configuration when backlights is enabled
    (mkIf cfg.enable {
      # These flags are used to enable backlight control when the dGPU is working in hybrid mode
      boot.kernelParams = [
        "i915.enable_dpcd_backlight=1"
        "nvidia.NVreg_EnableBacklightHandler=0"
        "nvidia.NVReg_RegistryDwords=EnableBrightnessControl=0"
      ];
    })
  ];
}
