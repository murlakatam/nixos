# herdr-core on the NUC (herdr-nix core flavour, see the herdr-nix-core skill). Copy of
# hosts/mediabox/herdr.nix minus the brain vault / github deploy-key aliases (mediabox-only).
{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];

  # herdr-core keeps running with nobody logged in.
  users.users.eugene.linger = true;

  # Laptop host key for Tailscale SSH (herd-evacuate delegates to it). Public key.
  programs.ssh.knownHosts."proartp16.tail328048.ts.net".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOX/nQ/S5JN3r2vsKTtBcBXfm3djn6PdewgXAcQ8V3Wy";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};
    users.eugene = {
      imports = [inputs.herdr-nix.homeManagerModules.default];
      home.stateVersion = "26.05";
      # Resume runs from zsh's initContent, so HM must own ~/.zshrc.
      programs.zsh.enable = true;
      herdr-nix.core.enable = true;
      herdr-nix.evacuate.appHost = "proartp16.tail328048.ts.net";
      # Claude Code for moved sessions / resume after reboot. Login is manual, once: `claude /login`.
      home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];
    };
  };
}
