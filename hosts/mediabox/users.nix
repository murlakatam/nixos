{pkgs, ...}: {
  users.users.eugene = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj11v6lmLPZOP/oC/TZyhKECdUMDVfDNX2XwkXZHG3M eugene.baranovsky@sharesies.com.au"
      # Herdr mobile app (attach to hc terminals from the phone).
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL4kymskwmAVRVt89dSGzy6fudEyhlDhx+UsezH/f+GN herdr-mobile"
    ];
  };
  programs.zsh.enable = true;
  # Write deploy key for murlakatam/nixos only (private key generated on this box, never copied).
  # A separate alias, so plain github.com (forwarded agent, private flake inputs) is unaffected.
  # The dotfiles checkout's origin is git@github-nixos:murlakatam/nixos.git.
  programs.ssh.extraConfig = ''
    Host github-nixos
      HostName github.com
      HostKeyAlias github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_github_nixos
      IdentitiesOnly yes
  '';
  # sudo is authenticated by the forwarded SSH agent (key must be in the root-owned
  # /etc/ssh/authorized_keys.d/%u). No agent forwarded => no sudo.
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  security.sudo.wheelNeedsPassword = true;
  # Fallback: without an agent, sudo asks eugene's Unix password (pam_unix after
  # ssh_agent_auth). That password was set by hand (`sudo passwd eugene`, 2026-11-14)
  # and lives only in /etc/shadow; it survives rebuilds because mutableUsers = true.
  # TODO: for full reproducibility (reinstall / mutableUsers = false), move it to sops:
  #   sops.secrets.eugene-password.neededForUsers = true;  # value: `mkpasswd -m yescrypt`
  #   users.users.eugene.hashedPasswordFile = config.sops.secrets.eugene-password.path;
  # (add `config` to the module args; after that, don't change it with passwd).
}
