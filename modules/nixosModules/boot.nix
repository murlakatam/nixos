{
  pkgs,
  config,
  ...
}: {
  boot = {
    #linuxPackages_latest
    #linuxPackages_xanmod_latest
    kernelPackages = pkgs.linuxPackages_zen;
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
