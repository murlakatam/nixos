{
  config,
  lib,
  pkgs,
  host,
  username,
  options,
  ...
}: let
  inherit (import ./variables.nix) keyboardLayout;
  globalEnvVars = import ./global-env-vars.nix {inherit pkgs;};
in {
  imports = [
    ./hardware.nix
    ./users.nix
    ../../modules/nixosModules
    ../../modules/drivers/amd-drivers.nix
    ../../modules/drivers/nvidia-drivers.nix
    ../../modules/drivers/nvidia-prime-drivers.nix
  ];

  # Make custom parameters available to all modules
  _module.args = {
    inherit host username;
  };

  # Drivers Options
  drivers.amdgpu.enable = true;
  drivers.nvidia.enable = false;
  drivers.nvidia-prime = {
    enable = false;
    amdgpuBusId = "PCI:101:0:0";
    nvidiaBusID = "PCI:100:0:0";
  };

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = host;

  # Set your time zone and NTP server.
  time.timeZone = "Australia/Sydney";
  networking.timeServers =
    options.networking.timeServers.default
    ++ ["au.pool.ntp.org"];

  # allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.variables = lib.mkDefault globalEnvVars;

  #docker replacement
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerSocket.enable = true;

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };

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
