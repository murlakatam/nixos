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
  # Per-repo write deploy keys (private keys generated on this box, never copied); GitHub
  # allows a deploy key on one repo only, hence one alias each. Separate aliases, so plain github.com (forwarded agent, private flake inputs) is unaffected.
  programs.ssh.extraConfig = ''
    Host github-nixos
      HostName github.com
      HostKeyAlias github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_github_nixos
      IdentitiesOnly yes
    # Write deploy key for murlakatam/brain only (knowledge-base vault sync, see herdr.nix).
    Host github-brain
      HostName github.com
      HostKeyAlias github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_github_brain
      IdentitiesOnly yes
  '';
  # The vault sync timer runs ssh in BatchMode, so it can't accept a host key. Public key,
  # from https://api.github.com/meta.
  programs.ssh.knownHosts."github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  # sudo is authenticated by the forwarded SSH agent (key must be in the root-owned
  # /etc/ssh/authorized_keys.d/%u). No agent forwarded => no sudo, except the Unix-password
  # fallback: set one by hand after install (`sudo passwd eugene`, mutableUsers = true).
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  security.sudo.wheelNeedsPassword = true;
}
