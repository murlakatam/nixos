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
}
