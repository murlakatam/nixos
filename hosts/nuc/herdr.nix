# herdr-core on the NUC (herdr-nix core flavour, see the herdr-nix-core skill). Based on
# hosts/mediabox/herdr.nix, including the brain vault (deploy-key aliases are in users.nix).
{
  inputs,
  outputs,
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
      imports = [
        inputs.herdr-nix.homeManagerModules.nocompat
        outputs.homeManagerModules.knowledge-base
        outputs.homeManagerModules.ai-permissions
        outputs.homeManagerModules.claude-code
        outputs.homeManagerModules.system-monitors
        outputs.homeManagerModules.cli-tools
        outputs.homeManagerModules.shells
        outputs.homeManagerModules.file-managers
        outputs.homeManagerModules.dev-tools
      ];
      # Shared CLI modules. file-managers is yazi only (Krusader stays off).
      dotfiles.system-monitors.enable = true;
      dotfiles.cli-tools.enable = true;
      dotfiles.shells.enable = true;
      dotfiles.file-managers.enable = true;
      dotfiles.dev-tools = {
        enable = true;
        lsps.enable = false;
        data-tools.enable = false;
      };
      # ai.permissions.* (herdr hooks + allow list) merged into ~/.claude/settings.json.
      dotfiles.ai-permissions.enable = true;
      # Shared Claude Code setup; headless, so no notifications or status line.
      dotfiles.claude-code = {
        enable = true;
        modelLabel.enable = true;
      };
      home.stateVersion = "26.05";
      # Resume runs from zsh's initContent, so HM must own ~/.zshrc.
      programs.zsh.enable = true;
      herdr-nix.core.enable = true;
      herdr-nix.evacuate.appHost = "proartp16.tail328048.ts.net";
      # FQDN: the short name fails host key checking (knownHosts above).
      herdr-nix.hcMachines.proartp16 = "proartp16.tail328048.ts.net";
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
      # Claude Code for moved sessions / resume after reboot. Login is manual, once: `claude /login`.
      home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];
    };
  };
}
