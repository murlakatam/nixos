{
  pkgs,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername gitEmail;
in {
  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
    firefox = {
      enable = true;
      # keep the legacy profile location (new default is XDG, needs a manual move)
      configPath = ".mozilla/firefox";
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
    home-manager.enable = true;
    # nix-ld = {
    #   enable = true;
    #   libraries = with pkgs; [
    #     icu
    #     gmp
    #     glibc
    #     openssl
    #     stdenv.cc.cc
    #   ];
    # };

    #yazi = {
    #  enable = true;
    #  package = pkgs.yazi.override {
    #    _7zz = pkgs._7zz.override {useUasm = true;};
    #  };
    #};
    # zathura = {
    #   enable = true;
    # };

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
