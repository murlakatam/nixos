# Intel NUC (192.168.0.52): lean server, free disk. Future use: stablecoin minting (undecided).
# Server bits are copied from hosts/mediabox/config.nix (not shared: mediabox is edited in parallel).
# Install procedure: docs/nuc-install.md.
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
    ./users.nix
    ./herdr.nix
  ];

  networking.hostName = "nuc";
  system.stateVersion = "26.05";

  dotfiles.tailscale = {
    enable = true;
    trustTailnet = true;
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hardware report: generated at install time by nixos-anywhere
  #   --generate-hardware-config nixos-facter hosts/nuc/facter.json   (then `git add` it).
  # Until it exists (build-check only), fall back to minimal initrd modules.
  hardware.facter.reportPath = lib.mkIf (builtins.pathExists ./facter.json) ./facter.json;
  boot.initrd.availableKernelModules = lib.mkIf (!builtins.pathExists ./facter.json) [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  # facter sets the platform from the report; the fallback needs it explicitly.
  nixpkgs.hostPlatform = lib.mkIf (!builtins.pathExists ./facter.json) "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;

  # Nix
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "eugene"];
  };

  zramSwap.enable = true;
  services.fstrim.enable = true;
  time.timeZone = "Australia/Sydney";

  # Firewall: SSH only (tailscale0 is trusted via dotfiles.tailscale)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };

  # Ethernet (eno1) via DHCP from NetworkManager's default wired profile. Wi-Fi (wlp58s0) is
  # a manual fallback: `nmtui` / `nmcli device wifi connect`.
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };

  # nuc.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    settings.publish = {
      "disable-publishing" = false;
      publish-addresses = true;
    };
  };

  # Never sleep
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    IdleAction = "ignore";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr
    git
    htop
    btop
    smartmontools
    nvme-cli
    lm_sensors
    pciutils
    usbutils
    rsync
    tmux
  ];
}
