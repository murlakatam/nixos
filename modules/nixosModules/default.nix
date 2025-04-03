{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./boot.nix
    ./packages.nix
    ./programs.nix
    ./services.nix
    ./environmentVariables.nix
    ./nix.nix
    ./hardware.nix
    ./users.nix
    ./i18n.nix
    ./fonts.nix
  ];
}
