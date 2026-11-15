# herdr-core on mediabox (herdr-nix core flavour, see the herdr-nix-core skill):
# terminals that survive SSH logout and reboots, attach with `hc` over SSH or
# from the laptop's Herdr app. Home-manager exists here only for this.
{
  inputs,
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
      imports = [inputs.herdr-nix.homeManagerModules.default];
      home.stateVersion = "26.05";
      # Resume runs from zsh's initContent, so HM must own ~/.zshrc.
      programs.zsh.enable = true;
      herdr-nix.core.enable = true;
      # Claude Code for sessions moved here (herd-evacuate) and for resume after
      # reboot. Login is manual, once: `ssh mediabox`, then `claude /login`.
      home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code];
    };
  };
}
