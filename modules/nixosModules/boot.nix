{
  pkgs,
  config,
  ...
}: {
  boot = {
    #linuxPackages_latest
    #linuxPackages_xanmod_latest
    #linuxPackages_zen
    kernelPackages = pkgs.linuxPackages_zen;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        consoleMode = "auto";
        enable = true;
        configurationLimit = 5;
      };
    };
    plymouth.enable = true;
  };
}
