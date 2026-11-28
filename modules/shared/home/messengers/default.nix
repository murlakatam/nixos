# Messengers. Threema 2.0 (beta) comes from Flathub as a user installation, through
# nix-flatpak's home-manager module, which the consumer imports:
#   imports = [inputs.nix-flatpak.homeManagerModules.nix-flatpak];
# nix-flatpak adds the flathub remote itself. Updates follow the consumer's
# services.flatpak.update settings (nix-flatpak default: never).
# On non-NixOS, point pkgs.flatpak at the host binary (overlay) so the distro's
# bwrap/apparmor setup is used.
{
  config,
  lib,
  options,
  ...
}: let
  cfg = config.dotfiles.messengers;
  hasFlatpak = options ? services.flatpak.packages;
in {
  options.dotfiles.messengers = {
    enable = lib.mkEnableOption "messenger apps";
    threema.enable = lib.mkEnableOption "Threema desktop from Flathub (needs nix-flatpak's HM module)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.threema.enable -> hasFlatpak;
          message = "dotfiles.messengers.threema needs nix-flatpak's home-manager module imported.";
        }
      ];
    }
    (lib.optionalAttrs hasFlatpak (lib.mkIf cfg.threema.enable {
      services.flatpak = {
        enable = true;
        packages = [
          {
            appId = "ch.threema.threema-desktop";
            origin = "flathub";
          }
        ];
      };
    }))
  ]);
}
