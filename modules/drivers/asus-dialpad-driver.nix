{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.drivers.asus-dialpad;
in {
  imports = [
    inputs.asus-dialpad-driver.nixosModules.default
  ];

  options.drivers.asus-dialpad = {
    # https://github.com/asus-linux-drivers/asus-dialpad-driver
    enable = mkEnableOption "Enable Asus Dialpad Driver support";
  };

  config = mkMerge [
    # Configuration when dialpad driver is enabled
    (mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        python311Packages.xcffib
      ];

      services.asus-dialpad-driver = {
        enable = true;
        layout = "proartp16";
        wayland = true;
        ignoreWaylandDisplayEnv = false;
        runtimeDir = "/run/user/1000/";
        waylandDisplay = "wayland-0";

        config = {
          main = {
            touchpad_disables_dialpad = false;
            disable_due_inactivity_time = 360;
          };
        };
      };
    })
  ];
}
