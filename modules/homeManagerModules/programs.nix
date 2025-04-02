{
  pkgs,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername gitEmail;
in {
  programs = {
    # btop = {
    #   enable = true;
    #   settings = {vim_keys = true;};
    # };

    # either use this or the one defined in ./fzf.nix

    # gh.enable = true;

    # Atuin shell history tool
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
      enableBashIntegration = true;
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
    # foot = {
    #   enable = true;
    #   server.enable = true;
    #   settings = {
    #     main = {
    #       term = "xterm-256color";
    #       font = "JetBrainsMono Nerd Font Mono:size=15";
    #       dpi-aware = "no";
    #     };
    #     mouse = {hide-when-typing = "yes";};
    #   };
    # };
    fzf = {
      enable = true;
      enableZshIntegration = true;
      # make fzf search hidden files too
      defaultCommand = "ag --hidden --ignore .git -g '' ";
    };
    home-manager.enable = true;
    git = {
      enable = true;
      userName = "${gitUsername}";
      userEmail = "${gitEmail}";
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

    #yazi = {
    #  enable = true;
    #  package = pkgs.yazi.override {
    #    _7zz = pkgs._7zz.override {useUasm = true;};
    #  };
    #};
    # zathura = {
    #   enable = true;
    # };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # hyprlock = {
    #   enable = true;
    #   settings = {
    #     general = {
    #       disable_loading_bar = true;
    #       grace = 10;
    #       hide_cursor = true;
    #       no_fade_in = false;
    #     };
    #     # background = [
    #     #   {
    #     #     path = "/home/${username}/Pictures/Wallpapers/Wall.png";
    #     #     blur_passes = 3;
    #     #     blur_size = 8;
    #     #   }
    #     # ];
    #     # image = [
    #     #   {
    #     #     path = "/home/${username}/.config/5-cm.jpg";
    #     #     size = 150;
    #     #     border_size = 4;
    #     #     border_color = "rgb(0C96F9)";
    #     #     rounding = -1; # Negative means circle
    #     #     position = "0, 200";
    #     #     halign = "center";
    #     #     valign = "center";
    #     #   }
    #     # ];
    #     # input-field = [
    #     #   {
    #     #     size = "200, 50";
    #     #     position = "0, -80";
    #     #     monitor = "";
    #     #     dots_center = true;
    #     #     fade_on_empty = false;
    #     #     font_color = "rgb(CFE6F4)";
    #     #     inner_color = "rgb(657DC2)";
    #     #     outer_color = "rgb(0D0E15)";
    #     #     outline_thickness = 5;
    #     #     placeholder_text = "Password...";
    #     #     shadow_passes = 2;
    #     #   }
    #     # ];
    #   };
    # };
    # starship = {
    #   enable = true;
    #   package = pkgs.starship;
    # };
  };
}
