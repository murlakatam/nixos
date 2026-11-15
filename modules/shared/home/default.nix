# Shared home-manager modules, exported as `homeManagerModules.<category>` (+ `.default` = all).
#
# Rules for every module here (this repo is PUBLIC):
#   - lives at ./<category>/default.nix and is plain home-manager;
#   - gated by `options.dotfiles.<category>.enable` (mkEnableOption, default false);
#   - no specialArgs (username, host, vars, dotfilesPath, globalEnvVars): only config/lib/pkgs;
#   - must evaluate on Ubuntu standalone HM and on NixOS HM;
#   - nothing private or work-specific.
#
# Consumer (any flake):
#   inputs.murlakatam-nixos = {url = "github:murlakatam/nixos"; inputs.nixpkgs.follows = "nixpkgs";};
#   # home.nix
#   imports = [inputs.murlakatam-nixos.homeManagerModules.default];
#   dotfiles.system-monitors.enable = true;
{inputs}: {
  system-monitors = ./system-monitors;
  default = {
    imports = [
      ./system-monitors
    ];
  };
}
