# herdr-core on the NUC (herdr-nix core flavour, see the herdr-nix-core skill). Based on
# hosts/mediabox/herdr.nix, minus the brain vault: the NUC is a sandbox with no GitHub or vault access.
{
  inputs,
  outputs,
  pkgs,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];

  # herdr-core keeps running with nobody logged in.
  users.users.eugene.linger = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};
    users.eugene = {
      imports = [
        inputs.herdr-nix.homeManagerModules.nocompat
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
      # Shared Claude Code setup; headless, so no notifications.
      dotfiles.claude-code = {
        enable = true;
        modelLabel.enable = true;
        statusLine = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ccstatusline;
        };
      };
      home.stateVersion = "26.05";
      # Resume runs from zsh's initContent, so HM must own ~/.zshrc.
      programs.zsh.enable = true;
      herdr-nix.core.enable = true;
      # Claude Code for moved sessions / resume after reboot. Login is manual, once: `claude /login`.
      home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];
    };
  };
}
