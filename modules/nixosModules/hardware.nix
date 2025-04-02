{pkgs, ...}: {
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    # scaner related shit
    # sane = {
    #   enable = true;
    #   extraBackends = [ pkgs.sane-airscan ];
    #   disabledDefaultBackends = [ "escl" ];
    # };
    # logitech.wireless = {
    #   enable = false;
    #   enableGraphical = false;
    # };
  };
}
