{
  pkgs,
  host,
  username,
  lib,
  config,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername;
in {
  options = {users.enable = lib.mkEnableOption "Enables users module";};

  config = lib.mkIf config.users.enable {
    users.users = {
      "${username}" = {
        homeMode = "755";
        isNormalUser = true;
        description = "${gitUsername}";
        extraGroups = [
          "networkmanager" # allows user to manage network connection
          "wheel" # allows user to execute commands as superuser
          #"libvirtd" manage virutal maching
          # "scanner" scanning
          #"lp" printing
        ];
        shell = pkgs.zsh;
        ignoreShellProgramCheck = true;
      };
    };

    users.defaultUserShell = pkgs.zsh;
  };
}
