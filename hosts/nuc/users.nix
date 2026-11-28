{pkgs, ...}: {
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
  # sudo is authenticated by the forwarded SSH agent (key must be in the root-owned
  # /etc/ssh/authorized_keys.d/%u). No agent forwarded => no sudo, except the Unix-password
  # fallback: set one by hand after install (`sudo passwd eugene`, mutableUsers = true).
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  security.sudo.wheelNeedsPassword = true;
}
