{
  pkgs,
  username,
  ...
}: let
  inherit (import ./variables.nix) gitUsername;
in {
  users.users = {
    "${username}" = {
      homeMode = "755";
      isNormalUser = true;
      description = "${gitUsername}";
      extraGroups = [
        "networkmanager" # allows user to manage network connection
        "wheel" # allows user to execute commands as superuser
        #"libvirtd" manage virutal maching
        # "scanner" scanning
        #"lp" printing
        "docker" # for dorker
        "video" # Grants permission to access video hardware like webcams and, crucially, graphics cards.
        "audio" # Grants direct access to sound hardware.
        "input" # Grants permission to read from input devices
        "uinput" # Grants permission to create virtual input devices.
        "i2c" # Grants permission to access the I2C bus (Inter-Integrated Circuit), a communication protocol used for internal hardware components.
      ];
      shell = pkgs.zsh;
      ignoreShellProgramCheck = true;
    };
  };

  environment.shells = with pkgs; [zsh];
}
