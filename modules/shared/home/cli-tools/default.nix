# Interactive CLI tools: atuin, bat, eza, fd, fzf, ripgrep, zoxide, tealdeer, navi,
# mdr, ast-grep, jq, yq.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.cli-tools;
  isZsh = cfg.shell == "zsh";
  isBash = cfg.shell == "bash";
  isFish = cfg.shell == "fish";
  integrations = {
    enableZshIntegration = isZsh;
    enableBashIntegration = isBash;
    enableFishIntegration = isFish;
  };
in {
  options.dotfiles.cli-tools = {
    enable = lib.mkEnableOption "interactive CLI tools (atuin, bat, eza, fd, fzf, ripgrep, zoxide, ...)";
    shell = lib.mkOption {
      type = lib.types.enum ["zsh" "bash" "fish"];
      default = "zsh";
      description = "Shell to wire the tools' integrations (keybindings, init) into.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."atuin/themes/catppuccin-mocha.toml".source = ./atuin-catppuccin-mocha.toml;

    # zoxide: print the target path before cd-ing
    home.sessionVariables._ZO_ECHO = "1";

    home.packages = with pkgs; [
      mdr # markdown renderer for the terminal
      ast-grep # structural code search by syntax tree
      jq # JSON processor
      yq # YAML/JSON/XML processor (jq wrapper)
    ];

    programs = {
      # shell history
      atuin =
        integrations
        // {
          enable = true;
          # atuin writes a default config.toml on first run; take it over.
          forceOverwriteSettings = true;
          settings = {
            enter_accept = true;
            style = "compact";
            theme.name = "catppuccin-mocha";
            sync.records = true;
          };
        };

      # cat with syntax highlighting
      bat = {
        enable = true;
        themes.catppuccin-mocha.src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme";
          hash = "sha256-OVVm8IzrMBuTa5HAd2kO+U9662UbEhVT8gHJnCvUqnc=";
        };
        config.theme = "catppuccin-mocha";
      };

      # ls replacement
      eza =
        integrations
        // {
          enable = true;
          git = true;
          icons = "auto";
        };

      # find replacement
      fd.enable = true;

      # fuzzy finder
      fzf =
        integrations
        // {
          enable = true;
          # search hidden files too
          defaultCommand = "fd --type f --hidden --exclude .git";
          # atuin owns Ctrl-R; keep fzf's other bindings (Ctrl-T, Alt-C)
          historyWidget.command = "";
        };

      # interactive cheatsheets
      navi = integrations // {enable = true;};

      # grep replacement
      ripgrep = {
        enable = true;
        arguments = [
          "--max-columns-preview"
          "--pretty"
        ];
      };

      # tldr client
      tealdeer = {
        enable = true;
        settings.updates.auto_update = true;
      };

      # cd that learns
      zoxide = integrations // {enable = true;};
    };
  };
}
