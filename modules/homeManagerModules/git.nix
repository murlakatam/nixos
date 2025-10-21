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

      settings = {
        alias = {
          pushup = "!git push --set-upstream origin `git symbolic-ref --short HEAD`";
        };
        user = {
          name = "${gitUsername}";
          email = "${gitEmail}";
        };
        core = {
          autocrlf = "input";
          editor = "code --wait";
        };
      };
    };
  };
}
