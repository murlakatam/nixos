{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    asusctl # ASUS laptop control utility
    supergfxctl # GPU switching utility, mostly for ASUS laptops
  ];

  services = {
    supergfxd.enable = true;
    asusd = {
      enable = true;
      enableUserService = true;
    };
  };
}
