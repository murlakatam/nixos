{
  config,
  pkgs,
  ...
}: {
  users.users.eugene = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj11v6lmLPZOP/oC/TZyhKECdUMDVfDNX2XwkXZHG3M"
      # Herdr mobile app (attach to hc terminals from the phone).
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL4kymskwmAVRVt89dSGzy6fudEyhlDhx+UsezH/f+GN herdr-mobile"
    ];
  };
  # Deploys log in as root with the laptop key only, so no agent forwarding is needed.
  users.users.root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj11v6lmLPZOP/oC/TZyhKECdUMDVfDNX2XwkXZHG3M"];
  programs.zsh.enable = true;
  # sudo: ssh-agent auth if an agent is forwarded (not done by default), else eugene's Unix
  # password (pam_unix). Its yescrypt hash lives in sops and sops is in charge: with
  # mutableUsers = false every activation re-applies it, so `passwd` changes don't stick.
  # Change it in secrets/nuc.yaml (`mkpasswd -m yescrypt` + `sops set`), then deploy. Root stays locked.
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  security.sudo.wheelNeedsPassword = true;
  users.mutableUsers = false;
  sops.secrets.eugene-password.neededForUsers = true;
  users.users.eugene.hashedPasswordFile = config.sops.secrets.eugene-password.path;
}
