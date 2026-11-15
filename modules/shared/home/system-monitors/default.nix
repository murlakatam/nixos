# Resource monitors and system info: btop, bottom, htop, fastfetch.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.system-monitors;
in {
  options.dotfiles.system-monitors = {
    enable = lib.mkEnableOption "system monitors (btop, bottom, htop, fastfetch)";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      btop = {
        enable = true;
        settings = {vim_keys = true;};
      };
      bottom = {
        enable = true;
        settings = {
          flags = {
            avg_cpu = true;
            color = "gruvbox";
            group_processes = true;
            tree = true;
            temperature_type = "c";
          };
        };
      };
      htop.enable = true;
    };
    home.packages = [pkgs.fastfetch];
  };
}
