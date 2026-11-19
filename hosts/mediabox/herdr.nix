# herdr-core on mediabox (herdr-nix core flavour, see the herdr-nix-core skill):
# terminals that survive SSH logout and reboots, attach with `hc` over SSH or
# from the laptop's Herdr app. Home-manager exists here only for this.
{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];

  # herdr-core keeps running with nobody logged in.
  users.users.eugene.linger = true;

  # Laptop host key for Tailscale SSH (herd-evacuate delegates to it). Public key,
  # as presented by the laptop; replaces a hand-added known_hosts entry.
  programs.ssh.knownHosts."proartp16.tail328048.ts.net".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOX/nQ/S5JN3r2vsKTtBcBXfm3djn6PdewgXAcQ8V3Wy";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};
    users.eugene = {
      imports = [
        inputs.herdr-nix.homeManagerModules.nocompat
        outputs.homeManagerModules.knowledge-base
        outputs.homeManagerModules.ai-permissions
      ];
      # ai.permissions.* (herdr hooks + allow list) merged into ~/.claude/settings.json.
      dotfiles.ai-permissions.enable = true;
      home.stateVersion = "26.05";
      # Resume runs from zsh's initContent, so HM must own ~/.zshrc.
      programs.zsh.enable = true;
      herdr-nix.core.enable = true;
      # No Herdr app here: herd-evacuate runs on the laptop over Tailscale SSH.
      herdr-nix.evacuate.appHost = "proartp16.tail328048.ts.net";
      # Claude Code for sessions moved here (herd-evacuate) and for resume after
      # reboot. Login is manual, once: `ssh mediabox`, then `claude /login`.
      # Brain vault as local files for agent sessions here (headless: no Obsidian). Synced
      # hourly through the github-brain deploy key alias (users.nix).
      dotfiles.knowledge-base = {
        enable = true;
        obsidian.enable = false;
        vaults.brain = {
          path = "/home/eugene/docs/brain";
          remote = "git@github-brain:murlakatam/brain.git";
        };
      };
      home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];
    };
  };
}
