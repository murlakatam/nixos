# Messengers. Threema 2.0 lives in NUR (nixpkgs' threema-desktop is the legacy 1.2.x client),
# so the consumer passes the package in, e.g.
#   (import inputs.nur {nurpkgs = pkgs; inherit pkgs;}).repos.herver.threema-desktop
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.messengers;
in {
  options.dotfiles.messengers = {
    enable = lib.mkEnableOption "messenger apps";
    threema.package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Threema desktop package (null = not installed).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.threema.package != null) cfg.threema.package;
  };
}
