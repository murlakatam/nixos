{
  host,
  pkgs,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) keyboardLayout;
in {
  services = {
    # Critical: Without this, ykman and the GUIs won't find the key.
    pcscd.enable = true;

    # Critical: This allows your user to access the key without 'sudo'.
    udev.packages = [pkgs.yubikey-personalization];

    # Enable usb auto-mounting
    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;

    # Enable the GNOME Desktop Environment.
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    #Configures the X Window System (X11 or Wayland)
    xserver = {
      enable = true;
      xkb = {
        layout = "${keyboardLayout}";
        variant = "";
      };
    };

    # Enables libinput, a library for handling input devices
    libinput.enable = true;
    # Enables periodic TRIM commands for SSD maintenance (Essential for systems with SSDs)
    fstrim.enable = true;

    #CUPS printing system
    printing = {
      enable = false;
      # drivers = [pkgs.hplipWithPlugin];
    };

    # Enable flatpak https://github.com/gmodena/nix-flatpak
    flatpak.enable = true;

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

      # Enable WirePlumber (the modern session manager)
      wireplumber.enable = true;
    };

    #Firmware update daemon
    # Allows updating device firmware using the LVFS (Linux Vendor Firmware Service)
    fwupd.enable = true;
  };
}
