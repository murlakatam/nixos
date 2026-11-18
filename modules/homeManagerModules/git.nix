# proartp16 git bits. Generic git config (aliases, ignores, lazygit/gh/pre-commit) is
# dotfiles.dev-tools in modules/shared/home/dev-tools.
{host, ...}: let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername gitEmail;
in {
  programs.git.settings = {
    user = {
      name = "${gitUsername}";
      email = "${gitEmail}";
    };
    core.editor = "code --wait";
  };
}
