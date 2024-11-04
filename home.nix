{
  pkgs,
  inputs,
  ...
}: {
  imports = with inputs; [
    # Whatever home manager modules go here
    #./hyprland.nix
  ];

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  home.username = "eugene";
  home.homeDirectory = "/home/eugene";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    zinit # zsh plugin manager
    cod # turn any --help into completion
    tree # pretty print directories
    fastfetch # flexx your OS : alternative to freshly deceased neofetch
    #silver-searcher # ag
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    meld # gui differ
    banner # print big banners
    figlet # better banners
    toilet # even better banners
    dust # disk usage for humans
    #yazi # file explorer
    sd # sed for humans
    telegram-desktop
    teams-for-linux
    jetbrains.rider
    jetbrains.webstorm
    tmux
    azure-cli
  ];

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

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
    bat = {
      enable = true;
      themes = {
        catppucin-mocha = {
          src = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme";
            hash = "sha256-UBuh6EeUhD5V9TjAo7hBRaGCt3KjkkO7QDxuaEBzN0s=";
          };
        };
      };
      config = {
        theme = "catppucin-mocha";
      };
    };
    bottom = {
      enable = true;
      settings = {
        flags = {
          avg_cpu = true;
          color = "gruvbox";
          group_processes = true;
          tree = true;
          temperature_type = "c";
        };
      };
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    eza = {
      enable = true;
      enableZshIntegration = true;
      git = true;
      icons = "auto";
    };
    fd = {
      enable = true;
    };
    firefox = {
      enable = true;
      languagePacks = [
        "en-GB"
        "be"
      ];
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
      # make fzf search hidden files too
      defaultCommand = "ag --hidden --ignore .git -g '' ";
    };
    git = {
      enable = true;
      userName = "Eugene Baranovsky";
      userEmail = "baranovsky.e@gmail.com";
      aliases = {
        pushup = "!git push --set-upstream origin `git symbolic-ref --short HEAD`";
      };
    };
    htop.enable = true;
    navi = {
      enable = true;
      enableZshIntegration = true;
    };
    ripgrep = {
      enable = true;
      arguments = [
        "--max-columns-preview"
        "--pretty"
      ];
    };
    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };
    oh-my-posh = {
      enable = true;
      enableZshIntegration = true;
    };
    #yazi = {
    #  enable = true;
    #  package = pkgs.yazi.override {
    #    _7zz = pkgs._7zz.override {useUasm = true;};
    #  };
    #};
    zsh = {
      enable = true;
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
        # DOCKER
        docker = "podman";
        # SHELL TOOLS
        # eza is a maintained fork of exa
        exa = "eza";
        # compatibility fix for latest versions of eza  with zsh-exa
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
        if [[ -f ~/.profile ]]; then
          source ~/.profile
        fi
      '';

      initExtraFirst = ''
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${./catppuccin.omp.json})"
      '';
    };
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05"; # Did you read the comment?
}
