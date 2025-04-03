{
  pkgs,
  username,
  host,
  ...
}: let
  inherit (import ../../hosts/${host}/variables.nix) keyboardLayout;
in {
  services = {
    #Configures the X Window System (X11 or Wayland)
    # Enable the X11 windowing system.
    xserver.enable = true;

    # Enable the GNOME Desktop Environment.
    xserver.displayManager.gdm.enable = true;
    xserver.desktopManager.gnome.enable = true;

    # Configure keymap in X11
    xserver.xkb = {
      layout = "by";
      variant = "";
    };
    # Enables libinput, a library for handling input devices
    #libinput.enable = true;
    # Enables periodic TRIM commands for SSD maintenance (Essential for systems with SSDs)
    fstrim.enable = true;

    #CUPS printing system
    printing = {
      enable = false;
      # drivers = [pkgs.hplipWithPlugin];
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

    #Firmware update daemon
    # Allows updating device firmware using the LVFS (Linux Vendor Firmware Service)
    #fwupd.enable = true;
  };
}
