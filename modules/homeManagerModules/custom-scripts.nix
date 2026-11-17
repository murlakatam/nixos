{
  pkgs,
  config,
  username,
  dotfilesPath,
  ...
}: {
  # rebuild Makefile
  home.file."Makefile".source = pkgs.replaceVars ../../Makefile {
    # This replaces @dotfilesPath@ in the Makefile with the actual path string
    dotfilesPath = dotfilesPath;
  };

  # get azure token
  home.file.".config/zsh/functions/get-azure-token.zsh" = {
    source = ../../scripts/get-azure-token.zsh;
    executable = true;
  };

  # mount local NUC
  home.file.".config/zsh/functions/mount-NUC.zsh" = {
    source = ../../scripts/mount-NUC.zsh;
    executable = true;
  };

  # opens ide with nohop
  home.file.".config/zsh/functions/open-ide-here.zsh" = {
    source = ../../scripts/open-ide-here.zsh;
    executable = true;
  };

  # token-efficient, non-interactive rebuild wrapper for AI agents.
  # Shipped as a real executable on PATH (not a zsh function) so it works from
  # any shell, including non-interactive agent shells. The script file defines
  # the function; the bin wrapper calls it. @dotfilesPath@ is substituted.
  home.packages = [
    (pkgs.writeScriptBin "nixos-rebuild-ai" ''
      #!${pkgs.zsh}/bin/zsh
      # one rebuild at a time per host (shared lock: dotfiles.shells, nix-rebuild-status)
      source ${config.dotfiles.shells.rebuildLock.script}
      ${builtins.replaceStrings ["@dotfilesPath@"] [dotfilesPath]
        (builtins.readFile ../../scripts/nixos-rebuild-ai.zsh)}
      nixos-rebuild-ai "$@"
    '')
  ];

  home.file."/mnt/Kindle".source =
    config.lib.file.mkOutOfStoreSymlink "/run/media/${username}/Kindle";
}
