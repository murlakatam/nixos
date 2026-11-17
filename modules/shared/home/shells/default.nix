# Shell setup: zsh (options, history, aliases, zinit + plugins, Alt+E/Alt+R fzf-finder),
# oh-my-posh catppuccin prompt, weekly zinit update timer, and the one-rebuild-at-a-time
# lock (nix-rebuild-lock.zsh, nix-rebuild-status). Host rebuild commands stay per-host:
# they wrap their work in `_nix_locked <label> <detail> <fn> [args]` from the lock script,
# which zsh sources here and other scripts can source via dotfiles.shells.rebuildLock.script.
#
# Expects dotfiles.cli-tools for eza/bat/fd/fzf/zoxide/atuin (aliases + plugins use them);
# it does not init any of them again.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.shells;
  isZsh = cfg.shell == "zsh";
  zinitHome = "$HOME/.local/share/zinit";
  rebuildStatus = pkgs.writeScriptBin "nix-rebuild-status" ''
    #!${pkgs.zsh}/bin/zsh
    ${builtins.readFile ./nix-rebuild-status.zsh}
  '';
in {
  options.dotfiles.shells = {
    enable = lib.mkEnableOption "zsh + zinit plugins, oh-my-posh prompt and the nix rebuild lock";
    shell = lib.mkOption {
      type = lib.types.enum ["zsh" "bash" "fish"];
      default = "zsh";
      description = "Interactive shell. The zsh config applies only to zsh; the prompt is wired into this shell (and bash).";
    };
    zinitUpdate.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Weekly systemd user timer running `zinit update --all` (Linux, zsh only).";
    };
    rebuildLock.script = lib.mkOption {
      type = lib.types.path;
      default = ./nix-rebuild-lock.zsh;
      readOnly = true;
      description = "zsh lock helpers (_nix_locked) for host rebuild scripts to source.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [rebuildStatus];

      programs.oh-my-posh = {
        enable = true;
        configFile = ./catppuccin.omp.json;
        enableZshIntegration = isZsh;
        enableBashIntegration = true;
        enableFishIntegration = cfg.shell == "fish";
      };
    }

    (lib.mkIf isZsh {
      home.packages = [pkgs.zinit];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion = {
          enable = true;
          highlight = "fg=#6f6c5d";
        };
        dotDir = "${config.xdg.configHome}/zsh";
        history = {
          path = "$HOME/.histfile";
          save = 10000;
          size = 10000;
        };
        sessionVariables = {
          # ALT+E(dit): fuzzy search for files to open in $EDITOR
          FZF_FINDER_EDITOR_BINDKEY = "^[e";
          # ALT+R(ead): fuzzy search for files to open with the default pager
          FZF_FINDER_PAGER_BINDKEY = "^[r";
          # fzf-finder searches hidden files too
          FZF_FINDER_FD_OPTS = "--hidden -t f";
        };
        shellAliases = {
          hm = "home-manager";
          quit = "exit";
          cat = "bat";
          find = "fd";
          # eza is a maintained fork of exa
          exa = "eza";
          ls = "eza --group-directories-first --icons --color-scale all";
          cd = "z";
          lg = "lazygit";
          j = "just";
        };
        # fast-syntax-highlighting (zinit, plugins.zsh) highlights; HM's highlighter stays off.
        syntaxHighlighting.enable = false;

        initContent = lib.mkMerge [
          (lib.mkOrder 550 ''
            setopt extendedglob nomatch notify
            unsetopt beep
            # ensure zinit data directories exist before sourcing
            local _zinit_home="${zinitHome}"
            mkdir -p "$_zinit_home"/{completions,snippets,plugins}
            # fix stale _zinit completion symlink after nix store path changes
            if [[ -L "$_zinit_home/completions/_zinit" ]] && [[ ! -e "$_zinit_home/completions/_zinit" ]]; then
              rm -f "$_zinit_home/completions/_zinit"
              ln -sf "${pkgs.zinit}/share/zinit/_zinit" "$_zinit_home/completions/_zinit"
            fi
            source "${pkgs.zinit}/share/zinit/zinit.zsh"
            source ${./plugins.zsh}
            source ${./nix-rebuild-lock.zsh}
          '')
          ''
            export PYTHONWARNINGS="ignore::FutureWarning"
            [[ -f ~/.secrets ]] && source ~/.secrets
            [[ -f ~/.profile ]] && source ~/.profile
            # per-host / per-skill shell functions
            for func in ~/.config/zsh/functions/*.zsh(N); do
              source "$func"
            done
          ''
        ];

        completionInit = ''
          autoload -Uz compinit
          # remove stale zcompdump if it references missing completions (e.g. dangling _zinit)
          local _zdump="''${ZDOTDIR:-$HOME}/.zcompdump"
          if [[ -f "$_zdump" ]] && ! compinit -C 2>/dev/null; then
            rm -f "$_zdump"
          fi
          compinit
          zinit cdreplay -q
        '';
      };

      systemd.user = lib.mkIf (cfg.zinitUpdate.enable && pkgs.stdenv.hostPlatform.isLinux) {
        timers.zinit-update = {
          Unit.Description = "zinit plugins update";
          Install.WantedBy = ["timers.target"];
          Timer = {
            OnCalendar = "weekly";
            Unit = "zinit-update.service";
            Persistent = true;
          };
        };
        services.zinit-update = {
          Unit.Description = "zinit plugins update";
          # interactive zsh so ~/.zshrc sources zinit
          Service.ExecStart = "${config.programs.zsh.package}/bin/zsh -i -c 'zinit update --all'";
        };
      };
    })
  ]);
}
