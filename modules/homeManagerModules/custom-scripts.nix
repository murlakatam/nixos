{
  pkgs,
  config,
  ...
}: {
  # rebuild Makefile
  home.file."Makefile" = {
    source = ../../Makefile;
  };

  # rebuild script
  home.file."rebuild.sh" = {
    # Assuming this module is in ~/dotfiles/nixos/modules/homeManagerModules/
    source = ../../scripts/rebuild.sh;
    executable = true;
  };

  # reload wifi script
  home.file."reload-wifi.zsh" = {
    source = ../../scripts/reload-wifi.zsh;
    executable = true;
  };

  # allow me to azure postgres
  home.file.".config/zsh/functions/allow-me-2-postgres.zsh" = {
    source = ../../scripts/allow-me-2-postgres.zsh;
    executable = true;
  };

  # allow me to azure mssql
  home.file.".config/zsh/functions/allow-me-2-mssql.zsh" = {
    source = ../../scripts/allow-me-2-mssql.zsh;
    executable = true;
  };

  # get azure token
  home.file.".config/zsh/functions/get-azure-token.zsh" = {
    source = ../../scripts/get-azure-token.zsh;
    executable = true;
  };

  # put azure token to pgpass
  home.file.".config/zsh/functions/put-azure-token-in-pgpass.zsh" = {
    source = ../../scripts/put-azure-token-in-pgpass.zsh;
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
