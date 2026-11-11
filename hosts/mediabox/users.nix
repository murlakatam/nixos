{pkgs, ...}: {
  users.users.eugene = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj11v6lmLPZOP/oC/TZyhKECdUMDVfDNX2XwkXZHG3M eugene.baranovsky@sharesies.com.au"
    ];
  };
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;
}
