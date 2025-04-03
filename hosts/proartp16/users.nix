{
  pkgs,
  username,
  ...
}: let
  inherit (import ./variables.nix) gitUsername;
in {
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
        "docker" # for dorker
      ];
      shell = pkgs.zsh;
      ignoreShellProgramCheck = true;
      packages = with pkgs; [
      ];
    };
  };
}
