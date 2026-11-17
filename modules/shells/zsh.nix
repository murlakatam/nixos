# proartp16-only zsh bits. The shared part (zsh core, zinit plugins, prompt, rebuild
# lock) is dotfiles.shells in modules/shared/home/shells.
{
  config,
  pkgs,
  globalEnvVars,
  lib,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) dotfilesDir;
  absDotfilesPath = "${config.home.homeDirectory}/${dotfilesDir}";
  # interactive `rebuild` (opens $EDITOR, then make system); @dotfilesPath@ substituted
  rebuildScript = pkgs.replaceVars ./rebuild.zsh {
    dotfilesPath = absDotfilesPath;
  };
in {
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkBefore ''
      export NIX_LD_LIBRARY_PATH="${globalEnvVars.NIX_LD_LIBRARY_PATH}"
      export NIX_LD="${globalEnvVars.NIX_LD}"
      # .NET tools
      export PATH="$PATH:${config.home.homeDirectory}/.dotnet/tools"
    '')
    (lib.mkOrder 560 ''
      source "${rebuildScript}"
    '')
    ''
      # Yazi file manager: cd to the dir yazi exits in
      y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }
    ''
  ];
}
