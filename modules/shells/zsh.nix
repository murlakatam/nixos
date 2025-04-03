{
  pkgs,
  host,
  username,
  inputs,
  globalEnvVars,
  ...
}: {
  home.packages = with pkgs; [
    zinit
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=#6f6c5d";
    };
    history = {
      path = "$HOME/.histfile";
      save = 10000;
      size = 10000;
    };
    sessionVariables = {
      # ALT+E(dit) : fuzzy search for files to open in $EDITOR
      FZF_FINDER_EDITOR_BINDKEY = "^[e";
      # ALT+R(ead) : fuzzy search for files to open with default pager
      FZF_FINDER_PAGER_BINDKEY = "^[r";
      # make fzf finder plugin search hidden files too
      FZF_FINDER_FD_OPTS = "--hidden -t f";
      # print path before cding for zoxide
      _ZO_ECHO = 1;
    };
    shellAliases = {
      # HOME MANAGER
      hm = "home-manager";
      # SHELL TOOLS
      # eza is a maintained fork of exa
      exa = "eza";
      # compatibility fix for latest versions of eza with zsh-exa
      ls = "eza --group-directories-first --icons --color-scale all";
      # zoxide
      cd = "z";
      # git
      lg = "lazygit";
      # just
      j = "just";
      rebuild = "~/rebuild.sh";
    };
    # set some zsh options
    # autocd = cd into into directories without typing cd
    # extendedglob = enable advanced globbing
    # nomatch = don't throw an error if a glob doesn't match
    # notify = notify when a job completes
    # unset beep = disable the bell sound
    # then
    # init zinit and load plugins
    initExtraBeforeCompInit = ''
      setopt extendedglob nomatch notify
      unsetopt beep
      # init zinit
      source "${pkgs.zinit}/share/zinit/zinit.zsh"
      source ${./plugins.zsh}
    '';
    completionInit = ''
      autoload -Uz compinit
      compinit
      zinit cdreplay -q
    '';
    initExtra = ''
      if [[ -f ~/.secrets ]]; then
        source ~/.secrets
      fi
      # can go in profileExtra
      if [[ -f ~/.profile ]]; then
        source ~/.profile
      fi

      # Yazi file manager function
      y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      #moe get azure token
      get-azure-token() {
        #az login --scope https://ossrdbms-aad.database.windows.net/.default --tenant e6d2d4cc-b762-486e-8894-4f5f440d5f31
        az account get-access-token --resource-type oss-rdbms | jq -r '.accessToken'
      }
    '';
    initExtraFirst = ''
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${./catppuccin.omp.json})"
      export CYPRESS_INSTALL_BINARY=0
      export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress
      export NIX_LD_LIBRARY_PATH="${globalEnvVars.NIX_LD_LIBRARY_PATH}"
      export NIX_LD="${globalEnvVars.NIX_LD}"
    '';

    syntaxHighlighting.enable = true;
  };

  systemd.user = {
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
      # force sh to run the update all in zsh interactive mode
      Service.ExecStart =
        toString
        (pkgs.writeShellScript "zinit-update.zsh" ''
          echo "Update zinit plugins"
          /usr/bin/env zsh -i -c "zinit update --all"
        '');
    };
  };
}
