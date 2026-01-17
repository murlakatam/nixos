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

  home.file."/mnt/Kindle".source = config.lib.file.mkOutOfStoreSymlink "/run/media/${username}/Kindle";
}
