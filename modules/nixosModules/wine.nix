{pkgs, ...}: {
  nixpkgs.config.wine.build = "wineWow";

  environment.systemPackages = with pkgs; [
    wineWowPackages.stable
    winetricks
  ];
}
