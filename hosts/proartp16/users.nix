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
      ];
      shell = pkgs.zsh;
      ignoreShellProgramCheck = true;
      packages = with pkgs; [
        tealdeer # troubleshooting tool for tracing systems (tldr strace)
        zoxide # cd override with mem
        mcfly #shell history override ctrl+r
        stow # command for managing symlinks
        tokei #counts code files in projects grouping by language
        obsidian #notes taking
      ];
    };
  };
}
