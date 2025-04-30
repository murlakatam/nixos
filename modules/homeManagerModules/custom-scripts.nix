{
  pkgs,
  config,
  ...
}: {
  # rebuild script a
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

  # opens ide with nohop
  home.file.".config/zsh/functions/open-ide-here.zsh" = {
    source = ../../scripts/open-ide-here.zsh;
    executable = true;
  };
}
