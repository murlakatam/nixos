{pkgs, ...}: {
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      # settings = {
      #   General = {
      #     FastConnectable = true;
      #     Experimental = true;
      #   };
      # };
    };
  };
}
