{
  pkgs,
  lib,
  username,
  host,
  system,
  inputs,
  outputs,
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

  # Set ssh config
  home.file.".ssh/config" = {
    # Use .text for inline content
    text = ''
      Host ssh.murfly.me
        ProxyCommand ${pkgs.cloudflared}/bin/cloudflared access ssh --hostname %h
    '';
  };

  nixpkgs.config.allowUnfree = true;

  # Important: Apply the same overlays to Home Manager's nixpkgs
  nixpkgs.overlays = builtins.attrValues outputs.overlays;

  # Home Manager locale settings
  home.language = {
    base = "be_BY.UTF-8";
    address = "en_AU.UTF-8";
    monetary = "en_AU.UTF-8";
    paper = "en_AU.UTF-8";
    time = "en_AU.UTF-8";
    numeric = "en_AU.UTF-8";
    measurement = "en_AU.UTF-8";
  };

  # Set environment variables globally in Home Manager
  # If you need to set environment variables explicitly
  home.sessionVariables =
    globalEnvVars
    // {
      # LANG mirrors the 'base' above
      LANG = "be_BY.UTF-8";

      # Ensure specific formats use Australia
      LC_NUMERIC = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";

      # Set Timezone to Sydney
      TZ = "Australia/Sydney";
    };

  # Import Program Configurations
  imports = [
    ../../modules/shells
    ../../modules/terms
    ../../modules/homeManagerModules
  ];

  #Configure GNOME settings via Home Manager
  #Kraken Wanker
  dconf.settings = {
    "org/gnome/system/locale" = {
      region = "en_AU.UTF-8";
    };

    "org/gnome/desktop/applications/terminal" = {
      exec = "${terminalExe}";
    };

    # Set keyboard shortcut for terminal.
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

  #udiskie (usb mount)
  services.udiskie = {
    enable = true;
    settings = {
      # workaround for
      # https://github.com/nix-community/home-manager/issues/632
      program_options = {
        # replace with your favorite file manager
        file_manager = "${terminalExe} -e ${pkgs.yazi}/bin/yazi";
      };
    };
  };
}
