{
  pkgs,
  config,
  ...
}: {
  boot = {
    #linuxPackages_latest
    #linuxPackages_zen
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };
    plymouth.enable = true;
  };
}
