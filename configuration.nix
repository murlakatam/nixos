# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  #latest kernel
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  #boot.kernelPackages = pkgs.linuxPackages_latest;
  
  #disable amd gpu
  #boot.blacklistedKernelModules = [ "amdgpu" ];

  boot.kernelParams = [ "amd_iommu=on" ];
  boot.initrd.kernelModules = ["nvidia" "nvidia_drm" "nvidia_uvm" "nvidia_modeset" ];
  

  # opengl
  hardware.opengl = {
    enable = true;
  };

  #Load nvidia driver for xorg and waylands
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    #modesetting is required
    modesetting.enable = true;
    #nvidia power management. enable this if having issues with nvidia coming from sleep
    powerManagement.enable = false;
    #experimental fine grained power management. only works on newer nvidia cards
    powerManagement.finegrained = false;
    #buggy open source kernel module (do not mix up with nouveau third party
    open = true;
    #enable nvidia settings menu
    # vulkan header; re-enable whenever
    # 0384602eac8bc57add3227688ec242667df3ffe3the hits stable.
    nvidiaSettings = true;
    #package selection
    package = let #config.boot.kernelPackages.nvidiaPackages.latest; #let

    
    # https://forums.developer.nvidia.com/t/linux-6-7-3-545-29-06-550-40-07-error-modpost-gpl-incompatible-module-nvidia-ko-uses-gpl-only-symbol-rcu-read-lock/280908/19
     rcu_patch = pkgs.fetchpatch {
       url = "https://github.com/gentoo/gentoo/raw/c64caf53/x11-drivers/nvidia-drivers/files/nvidia-drivers-470.223.02-gpl-pfn_valid.patch";
        hash = "sha256-eZiQQp2S/asE7MfGvfe6dA/kdCvek9SYa/FFGp24dVg=";
      };
      # Fixes framebuffer with linux 6.11
      fbdev_linux_611_patch = pkgs.fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/NVIDIA/open-gpu-kernel-modules/pull/692.patch";
        hash = "sha256-OYw8TsHDpBE5DBzdZCBT45+AiznzO9SfECz5/uXN5Uc=";
      };
    in
      config.boot.kernelPackages.nvidiaPackages.mkDriver {
        #legacy 535
        #version = "535.154.05";
        #sha256_64bit = "sha256-fpUGXKprgt6SYRDxSCemGXLrEsIA6GOinp+0eGbqqJg=";
        #sha256_aarch64 = "sha256-G0/GiObf/BZMkzzET8HQjdIcvCSqB1uhsinro2HLK9k=";
        #openSha256 = "sha256-wvRdHguGLxS0mR06P5Qi++pDJBCF8pJ8hr4T8O6TJIo=";
        #settingsSha256 = "sha256-9wqoDEWY4I7weWW05F4igj1Gj9wjHsREFMztfEmqm10=";
        #persistencedSha256 = "sha256-d0Q3Lk80JqkS1B54Mahu2yY/WocOqFFbZVBh+ToGhaE=";
        #patches = [ rcu_patch ];

        #not used
        #version = "550.40.07";
        #sha256_64bit = "sha256-KYk2xye37v7ZW7h+uNJM/u8fNf7KyGTZjiaU03dJpK0=";
        #sha256_aarch64 = "sha256-AV7KgRXYaQGBFl7zuRcfnTGr8rS5n13nGUIe3mJTXb4=";
        #openSha256 = "sha256-mRUTEWVsbjq+psVe+kAT6MjyZuLkG2yRDxCMvDJRL1I=";
        #settingsSha256 = "sha256-c30AQa4g4a1EHmaEu1yc05oqY01y+IusbBuq+P6rMCs=";
        #persistencedSha256 = "sha256-11tLSY8uUIl4X/roNnxf5yS2PQvHvoNjnd2CB67e870=";
        #patches = [ rcu_patch ];

        #from nix forum (builds but fails to load)
        version = "555.58.02";
        sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
        sha256_aarch64 = "sha256-wb20isMrRg8PeQBU96lWJzBMkjfySAUaqt4EgZnhyF8=";
        openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
        persistencedSha256 = "sha256-a1D7ZZmcKFWfPjjH1REqPM5j/YLWKnbkP9qfRyIyxAw=";

        #beta
        #version = "560.31.02";
        #sha256_64bit = "sha256-0cwgejoFsefl2M6jdWZC+CKc58CqOXDjSi4saVPNKY0=";
        #sha256_aarch64 = "sha256-m7da+/Uc2+BOYj6mGON75h03hKlIWItHORc5+UvXBQc=";
        #openSha256 = "sha256-X5UzbIkILvo0QZlsTl9PisosgPj/XRmuuMH+cDohdZQ=";
        #settingsSha256 = "sha256-A3SzGAW4vR2uxT1Cv+Pn+Sbm9lLF5a/DGzlnPhxVvmE=";
        #persistencedSha256 = "sha256-BDtdpH5f9/PutG3Pv9G4ekqHafPm3xgDYdTcQumyMtg=";

        #latest
        #version = "560.35.03";
        #sha256_64bit = "sha256-8pMskvrdQ8WyNBvkU/xPc/CtcYXCa7ekP73oGuKfH+M=";
        #sha256_aarch64 = "sha256-s8ZAVKvRNXpjxRYqM3E5oss5FdqW+tv1qQC2pDjfG+s=";
        #openSha256 = "sha256-/32Zf0dKrofTmPZ3Ratw4vDM7B+OgpC4p7s+RHUjCrg=";
        #settingsSha256 = "sha256-kQsvDgnxis9ANFmwIwB7HX5MkIAcpEEAHc8IBOLdXvk=";
        #persistencedSha256 = "sha256-E2J2wYYyRu7Kc3MMZz/8ZIemcZg68rkzvqEwFAL3fFs=";
        #patchesOpen = [fbdev_linux_611_patch];
      };
  };

  # nvidia prime (hybrid offload to nvidia only if needed)
  hardware.nvidia.prime = {
  offload = {
     enable = true;
     enableOffloadCmd = true;
   };
   amdgpuBusId = "PCI:101:0:0";
   nvidiaBusId = "PCI:100:0:0";
 };

  # Bluetooth
  #hardware.bluetooth = {
  #  enable = true;
  #  powerOnBoot = true;
  #};

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "be_BY.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_NZ.UTF-8";
    LC_IDENTIFICATION = "en_NZ.UTF-8";
    LC_MEASUREMENT = "en_NZ.UTF-8";
    LC_MONETARY = "en_NZ.UTF-8";
    LC_NAME = "en_NZ.UTF-8";
    LC_NUMERIC = "en_NZ.UTF-8";
    LC_PAPER = "en_NZ.UTF-8";
    LC_TELEPHONE = "en_NZ.UTF-8";
    LC_TIME = "en_NZ.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "by";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "by";

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.eugene = {
    isNormalUser = true;
    description = "eugene";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # zsh
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Install firefox.
  programs.firefox.enable = true;
  # Install direnv
  programs.direnv.enable = true;

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = let
    nvidiaEnabled = lib.elem "nvidia" config.services.xserver.videoDrivers;
  in
    (with pkgs; [
      #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      #  wget
      git
      alejandra
      vscode
      libnotify
      pciutils
      inxi
      lshw
    ])
    ++ lib.optionals nvidiaEnabled [
      (config.hardware.nvidia.package.settings.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [pkgs.vulkan-headers];
      }))
    ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
