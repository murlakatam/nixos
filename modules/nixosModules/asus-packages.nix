{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    asusctl # ASUS laptop control utility
    supergfxctl # GPU switching utility, mostly for ASUS laptops
    gnomeExtensions.gpu-supergfxctl-switch # GNOME extension to integrate supergfxctl with GNOME Shell
  ];
}
