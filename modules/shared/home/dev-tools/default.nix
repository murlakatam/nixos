# Developer tools: git (generic aliases, global ignores, lazygit/gh/pre-commit), direnv +
# nix-direnv, shellcheck, alejandra, mkcert (package only), language servers and data tools
# (visidata, tennis, pandoc).
#
# Per host, NOT here: git identity (user.name/email, signing keys), includeIf for work dirs,
# credential helpers, core.editor/sshCommand, direnv whitelists, `mkcert -install` / CA trust,
# language toolchains/SDKs.
#
# direnv is hooked into the shell only by HM's integration (home.shell.enableShellIntegration);
# the shells module no longer loads a zinit direnv plugin, so `direnv hook` runs once per shell.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.dev-tools;
  # not in nixpkgs; a consumer's own overlay wins
  tennis = pkgs.tennis or (pkgs.callPackage ./tennis.nix {});
  csv = cfg.data-tools.csvDefault;
  visidata-csv = pkgs.writeShellScriptBin "visidata-csv" ''
    exec ${csv.terminal} ${pkgs.visidata}/bin/vd "$1"
  '';
  enabledByDefault = desc:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "${desc} (only when dotfiles.dev-tools.enable is set).";
    };
in {
  options.dotfiles.dev-tools = {
    enable = lib.mkEnableOption "developer tools (git, direnv, linters, language servers, data tools)";
    git = {
      enable = enabledByDefault "git with generic aliases and global ignores, plus lazygit, gh and pre-commit";
      ignores = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          # direnv & nix local environment
          ".envrc"
          ".direnv"
          ".direnv/"
          "shell.nix"
          # herdr-plus per-repo quick actions (kept local)
          ".herdr-plus/"
          # claude code local config
          "**/.claude/settings.local.json"
          "CLAUDE.local.md"
          # oh-my-claudecode state
          ".omc/"
          # kungfu project state (local index/cache)
          ".kungfu/"
        ];
        description = "Global git ignore patterns.";
      };
    };
    direnv.enable = enabledByDefault "direnv with nix-direnv";
    lsps = {
      enable = enabledByDefault "language servers (nix, bash, yaml, json/html/css, lua, markdown, C#, TypeScript, Python)";
      python.enable = enabledByDefault "pylsp (python-lsp-server, low priority: a host's own pylsp env with plugins wins)";
    };
    data-tools = {
      enable = enabledByDefault "data tools (visidata, tennis, pandoc)";
      csvDefault = {
        enable = lib.mkEnableOption "visidata as the default text/csv app (a visidata-csv wrapper + desktop entry; turns on xdg.mimeApps, so HM manages mimeapps.list)";
        terminal = lib.mkOption {
          type = lib.types.str;
          default = "ghostty -e";
          description = "Command prefix that runs a program in a new terminal window.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = with pkgs; [
        shellcheck # static analysis for shell scripts
        alejandra # nix formatter
        mkcert # local dev CA + certs (CA install is host-side)
      ];
    }

    (lib.mkIf cfg.git.enable {
      programs.git = {
        enable = true;
        signing.format = lib.mkDefault null;
        ignores = cfg.git.ignores;
        settings = {
          alias = {
            pushup = "!git push --set-upstream origin `git symbolic-ref --short HEAD`";
            please = "push --force-with-lease";
            yolo = "push --force-with-lease";
          };
          core.autocrlf = lib.mkDefault "input";
        };
      };
      home.packages = with pkgs; [
        lazygit
        gh # GitHub CLI
        pre-commit # multi-language pre-commit hooks
      ];
    })

    (lib.mkIf cfg.direnv.enable {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    })

    (lib.mkIf (cfg.lsps.enable && cfg.lsps.python.enable) {
      home.packages = [(lib.lowPrio pkgs.python3Packages.python-lsp-server)];
    })

    (lib.mkIf cfg.lsps.enable {
      home.packages = with pkgs; [
        nixd
        bash-language-server
        yaml-language-server
        vscode-langservers-extracted # json, html, css, eslint
        lua-language-server
        marksman # markdown
        csharp-ls
        typescript-language-server
        typescript # tsserver, needed by typescript-language-server
      ];
    })

    (lib.mkIf cfg.data-tools.enable {
      home.packages =
        [tennis]
        ++ (with pkgs; [
          visidata # terminal spreadsheet (CSV, TSV, JSON, ...)
          pandoc # document format converter
        ]);
    })

    (lib.mkIf (cfg.data-tools.enable && csv.enable) {
      home.packages = [visidata-csv];
      xdg.desktopEntries.visidata-csv = {
        name = "VisiData";
        exec = "${visidata-csv}/bin/visidata-csv %f";
        icon = "utilities-terminal";
        mimeType = ["text/csv"];
        terminal = false;
        type = "Application";
      };
      xdg.mimeApps = {
        enable = true;
        defaultApplications."text/csv" = ["visidata-csv.desktop"];
      };
    })
  ]);
}
