{
  pkgs,
  lib,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername gitEmail;
in {
  programs = {
    git = {
      enable = true;
      userName = "${gitUsername}";
      userEmail = "${gitEmail}";
      aliases = {
        pushup = "!git push --set-upstream origin `git symbolic-ref --short HEAD`";
      };
    };
  };
}
