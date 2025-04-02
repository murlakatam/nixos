{
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) keyboardLayout;
in {
  services = {
    #Configures the X Window System (X11)
    xserver = {
      enable = true;
      # Enable the GNOME Desktop Environment.
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      xkb = {
        layout = "${keyboardLayout}";
        variant = "";
      };
    };
    #Monitors storage devices for potential failures using S.M.A.R.T technology
    smartd = {
      enable = true;
      autodetect = true;
    };
    # Enables libinput, a library for handling input devices
    libinput.enable = true;
    # Enables periodic TRIM commands for SSD maintenance (Essential for systems with SSDs)
    fstrim.enable = true;
    # Enables GNOME Virtual File System
    gvfs.enable = true;
    #  OpenSSH server
    openssh.enable = false;
    # Flatpak containerized applications deployment system
    flatpak.enable = false;
    #CUPS printing system
    printing = {
      enable = false;
      # drivers = [pkgs.hplipWithPlugin];
    };
    gnome.gnome-keyring.enable = true;
    # Implements mDNS/DNS-SD (Zeroconf) protocol
    # avahi = {
    #   enable = true;
    #   nssmdns4 = true;
    #   openFirewall = true;
    # };
    #Makes USB printers available on the network using IPP protocol
    ipp-usb.enable = false;
    #Cross-device file synchronization
    syncthing = {
      enable = false;
      user = "${username}";
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";
    };
    # Enable sound with pipewire.
    pulseaudio.enable = false;
    pipewire = {
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
    #Profile-sync-daemon for browser profile management
    psd = {
      enable = true;
      resyncTimer = "1h";
    };
    # ollama LLM manager (can be forced to use AMD GPU)
    ollama = {
      enable = false;
      acceleration = "rocm";
      environmentVariables = {
        HCC_AMDGPU_TARGET = "gfx1102"; # we want it to be gfx1150, but it is not yet available
      };
      rocmOverrideGfx = "11.0.2"; # we want it to be "11.5.0" aka gfx1150, but it is not yet available;
    };
    #Firmware update daemon
    # Allows updating device firmware using the LVFS (Linux Vendor Firmware Service)
    fwupd.enable = true;
    # NFS-related services (Would enable NFS file sharing if enabled)
    rpcbind.enable = false;
    nfs.server.enable = false;
    # bluetooth manager
    blueman.enable = false;
  };
}
