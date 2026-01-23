{
  config,
  lib,
  pkgs,
  inputs,
  host,
  username,
  options,
  globalEnvVars,
  ...
}: let
  inherit (import ./variables.nix) dotfilesDir;
in {
  imports = with inputs; [
    ./hardware.nix
    home-manager.nixosModules.default
    ./users.nix
    ../../modules/nixosModules
    ../../modules/nixosModules/asus-packages.nix
    ../../modules/nixosModules/gnome-extensions.nix
    ../../modules/drivers/asus-dialpad-driver.nix
    ../../modules/drivers/amd-drivers.nix
    ../../modules/drivers/nvidia-drivers.nix
    ../../modules/drivers/nvidia-prime-drivers.nix
  ];

  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

  # asus ec sensors https://github.com/zeule/asus-ec-sensors
  boot.extraModulePackages = [
    (pkgs.callPackage ../../kernel-packages/asus-ec-sensors {
      kernel = config.boot.kernelPackages.kernel;
    })
  ];

  # Drivers Options
  # Enable AMD GPU drivers
  drivers.amdgpu.enable = true;
  drivers.nvidia.enable = true;
  drivers.nvidia-prime.enable = true;
  # Enable Asus Dialpad Driver
  drivers.asus-dialpad.enable = true;
  # xbox controller
  hardware.xone.enable = true;

  #Gnome extensions
  # removing battery extension for now as it seems not to be working properly
  desktop.gnome.batteryExtension.enable = false;

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = host;

  time.timeZone = "Australia/Sydney";
  networking.timeServers =
    options.networking.timeServers.default
    ++ ["au.pool.ntp.org"];

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.variables = lib.mkDefault globalEnvVars;

  #docker
  virtualisation.docker.enable = true;

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "path:home/${username}/${dotfilesDir}";
  };

  # security.rtkit is optional but highly recommended for PipeWire stability
  security.rtkit.enable = true;

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
