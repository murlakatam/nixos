{
  pkgs,
  lib,
  inputs,
  username,
  outputs,
  globalEnvVars,
  ...
}: let
  inherit (import ./variables.nix) terminal dotfilesDir;
  # Function to get the terminal executable path
  getTerminalExe = terminalName:
    if terminalName == "ghostty"
    then lib.getExe pkgs.ghostty
    else if terminalName == "gnome-terminal"
    then lib.getExe pkgs.gnome-terminal
    else terminalName; # Fallback to the name itself if not found

  terminalExe = getTerminalExe terminal;
in {
  _module.args.dotfilesPath = "/home/${username}/${dotfilesDir}";
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
      # Untracked per-machine hosts (real HostNames kept out of this public repo),
      # e.g. ~/.ssh/config.d/work: `Host work` / `HostName <magicdns>`.
      Include ~/.ssh/config.d/*

      # Work laptop over Tailscale SSH (HostName in ~/.ssh/config.d/work); used by hc.
      Host work
        User eugene

      Host ssh-mediabox.murfly.me
        User eugene
        ForwardAgent yes
        ProxyCommand ${pkgs.cloudflared}/bin/cloudflared access ssh --hostname %h

      Host mediabox 192.168.0.81
        HostName 192.168.0.81
        User eugene
        ForwardAgent yes

      Host nuc 192.168.0.52
        HostName 192.168.0.52
        User eugene
        ForwardAgent yes
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
    ../../modules/homeManagerModules
    inputs.herdr-nix.homeManagerModules.nocompat # ai.permissions comes from ai-permissions below
    outputs.homeManagerModules.default
  ];

  # Shared HM modules from this repo (modules/shared/home).
  dotfiles.system-monitors.enable = true;
  dotfiles.cli-tools.enable = true;
  dotfiles.shells.enable = true;
  dotfiles.terminals.enable = true;
  dotfiles.file-managers = {
    enable = true;
    krusader = {
      enable = true;
      mountCommand = "/run/wrappers/bin/mount";
    };
  };
  dotfiles.dev-tools.enable = true;
  dotfiles.meeting-recorder = {
    enable = true;
    whisper.acceleration = "vulkan";
  };
  dotfiles.knowledge-base = {
    enable = true;
    vaults.brain = {
      path = "/home/${username}/docs/brain";
      remote = "git@github.com:murlakatam/brain.git";
    };
  };

  # ai.permissions.* (herdr, skills) merged into ~/.claude/settings.json.
  dotfiles.ai-permissions.enable = true;
  # Shared Claude Code setup: CLAUDE.md, deny baseline, notify + model-label hooks.
  dotfiles.claude-code = {
    enable = true;
    notify.enable = true;
    modelLabel.enable = true;
    statusLine.enable = true;
  };

  # herdr flavours (private herdr-nix flake; setup skills: herdr-nix-app/-tui/-core).
  herdr-nix = {
    app.enable = true; # implies core: Claude resumes after reboot
    tui.enable = true;
    machines = ["mediabox"];
    # hc machines (name -> ssh target), added on activation if missing.
    # work is forward-only: its WARP blocks connections back into the tailnet.
    hcMachines = {
      work = "work";
      mediabox = "mediabox";
      nuc = "nuc";
    };
  };

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
