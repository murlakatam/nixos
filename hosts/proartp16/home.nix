{
  pkgs,
  lib,
  username,
  host,
  system,
  inputs,
  globalEnvVars,
  ...
}: let
  inherit (import ./variables.nix) terminal gitUsername gitEmail;
  # Function to get the terminal executable path
  getTerminalExe = terminalName:
    if terminalName == "ghostty"
    then lib.getExe pkgs.ghostty
    #else if terminalName == "alacritty" then lib.getExe pkgs.alacritty
    else if terminalName == "kitty"
    then lib.getExe pkgs.kitty
    else if terminalName == "gnome-terminal"
    then lib.getExe pkgs.gnome-terminal
    #else if terminalName == "wezterm" then lib.getExe pkgs.wezterm
    #else if builtins.hasAttr terminalName pkgs then lib.getExe pkgs.${terminalName}
    else terminalName; # Fallback to the name itself if not found

  terminalExe = getTerminalExe terminal;
in {
  # Home Manager Settings
  home.username = "${username}";
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.05";
  # Set avatar
  home.file.".face".source = ../../modules/avatars/Profile.png;
  nixpkgs.config.allowUnfree = true;

  # Home Manager locale settings
  home.language = {
    base = "en_NZ.UTF-8";
    address = "en_NZ.UTF-8";
    monetary = "en_NZ.UTF-8";
    paper = "en_NZ.UTF-8";
    time = "en_NZ.UTF-8";
    numeric = "en_NZ.UTF-8"; # This is particularly important for number formatting
  };

  # Set environment variables globally in Home Manager
  # If you need to set environment variables explicitly
  home.sessionVariables =
    globalEnvVars
    // {
      LANG = "en_NZ.UTF-8";
      LC_ALL = "en_NZ.UTF-8";
      LC_NUMERIC = "en_NZ.UTF-8";
    };

  # Import Program Configurations
  imports = [
    ../../modules/shells
    ../../modules/terms
    ../../modules/homeManagerModules
  ];

  #Configure GNOME settings via Home Manager
  dconf.settings = {
    "org/gnome/desktop/applications/terminal" = {
      exec = "${terminalExe}";
    };

    # Set keyboard shortcut for terminal
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Primary><Alt>t";
      command = "${terminalExe}";
      name = "Launch Terminal";
    };

    # Enable custom keybindings
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    # wallpaper
    "org/gnome/desktop/background" = {
      picture-uri = "file:///home/${username}/Pictures/Wallpapers/nix.png";
      picture-uri-dark = "file:///home/${username}/Pictures/Wallpapers/Crimson-Shadows-4k.jpg";
      picture-options = "zoom";
    };
  };
}
