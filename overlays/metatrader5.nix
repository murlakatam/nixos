final: prev: {
  # Use wineWowPackages which includes wine-gecko and wine-mono
  winePackages = prev.wineWowPackages;

  # Define the package with the correct dependencies
  metatrader5 = final.callPackage ../pkgs/metatrader5 {
    wine64 = final.winePackages.stable;
    # Use winetricks to install these components instead
    wine-gecko = null;
    wine-mono = null;
  };
}
