{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./disko.nix
    ./users.nix
    ./secrets.nix
  ];

  networking.hostName = "mediabox";
  system.stateVersion = "26.05";

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.facter.reportPath = ./facter.json;

  # Nix
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "eugene"];
  };
  nixpkgs.config.allowUnfree = true;

  # TEMPORARY until a dedicated media disk is added: /srv/media is a btrfs
  # subvolume @media on the backup HDD.
  # The subvolume was created once by hand: `btrfs subvolume create /srv/backup/@media`.
  # The NUC keeps its copy of the media meanwhile, so /srv/backup is not a backup of it.
  # Remove this when the new media disk is added in disko.nix.
  # Ownership: root for now; chown to the media user/group once Plex etc. exist.
  fileSystems."/srv/media" = {
    device = "/dev/disk/by-partlabel/disk-backup-backup";
    fsType = "btrfs";
    options = ["subvol=@media" "compress=zstd:1" "noatime" "nofail"];
  };

  zramSwap.enable = true;
  services.fstrim.enable = true;
  time.timeZone = "Australia/Sydney";

  # Firewall: SSH only
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };

  # mediabox.local
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

  # SSH
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

  # Graphics: Intel UHD 630 (Quick Sync) + NVIDIA GTX 1060 (Pascal)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    open = false;
    # Pascal is only supported up to the 580 branch.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    nvidiaPersistenced = true;
  };

  # Networking: Wi-Fi (wlp2s0) via NetworkManager profile, ethernet (enp3s0) via DHCP
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    ensureProfiles = {
      environmentFiles = [config.sops.secrets."wifi-env".path];
      profiles.wifi = {
        connection = {
          id = "wifi";
          type = "wifi";
          interface-name = "wlp2s0";
          autoconnect = true;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "$WIFI_SSID";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$WIFI_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
