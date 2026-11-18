# Terminal emulators. Today: ghostty only (pane nav ctrl+hjkl, shift+enter, jump_to_prompt,
# dark palette). Dropping ghostty later is one line: dotfiles.terminals.ghostty.enable = false.
#
# Host-side (not here): GPU wrappers such as nixGL on non-NixOS, launcher/keybinding commands,
# and `programs.ghostty.settings.command` when the login shell isn't the interactive one.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.terminals;
in {
  options.dotfiles.terminals = {
    enable = lib.mkEnableOption "terminal emulator configs (ghostty)";
    ghostty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure ghostty (only when dotfiles.terminals.enable is set).";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.ghostty;
        defaultText = lib.literalExpression "pkgs.ghostty";
        description = "ghostty package to install; null writes the config only (e.g. a distro package).";
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.ghostty.enable) {
    programs.ghostty = {
      enable = true;
      inherit (cfg.ghostty) package;
      installVimSyntax = true;
      settings = {
        keybind = [
          "ctrl+h=goto_split:left"
          "ctrl+j=goto_split:bottom"
          "ctrl+k=goto_split:top"
          "ctrl+l=goto_split:right"
          "ctrl+page_up=jump_to_prompt:-1"
          # newline without submit (Claude Code and other TUIs)
          "shift+enter=text:\\x1b\\r"
        ];

        window-colorspace = "display-p3";
        background = "#171717";
        foreground = "#C5C8C6";
        palette = [
          "0=#282a2e"
          "1=#D74E6F"
          "2=#31BB71"
          "3=#D3E561"
          "4=#8056FF"
          "5=#ED61D7"
          "6=#04D7D7"
          "7=#C5C8C6"
          "8=#4B4B4B"
          "9=#FE5F86"
          "10=#00D787"
          "11=#EBFF71"
          "12=#8F69FF"
          "13=#FF7AEA"
          "14=#00FEFE"
          "15=#FFFFFF"
        ];

        font-size = 12;
        font-family = "JetBrains Mono Light";

        adjust-cursor-thickness = "175%";
        cursor-style = "block";
        cursor-style-blink = false;
        link-url = true;
        window-decoration = true;
        confirm-close-surface = false;

        unfocused-split-opacity = 0.8;
        background-opacity = 0.9;
        background-blur-radius = 20;

        window-padding-x = 4;
        window-padding-y = 4;
        window-padding-color = "extend";

        window-theme = "dark";

        shell-integration-features = "sudo,ssh-terminfo,ssh-env";
      };
    };
  };
}
