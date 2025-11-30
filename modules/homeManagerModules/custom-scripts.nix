{
  pkgs,
  config,
  ...
}: {
  # rebuild Makefile
  home.file."Makefile" = {
    source = ../../Makefile;
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
}
