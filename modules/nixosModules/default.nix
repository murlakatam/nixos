{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./boot.nix
    # ./stylix.nix
    ./packages.nix
    ./programs.nix
    ./services.nix
    ./security.nix
    ./environmentVariables.nix
    ./nix.nix
    ./hardware.nix
    ./users.nix
    #./zram.nix
    ./i18n.nix
    ./fonts.nix
    # ./guix.nix GNU store?
    ./cachix.nix
    # ./thunar.nix file manager from xfce
    # ./dns.nix
    # ./firewall.nix
  ];
}
