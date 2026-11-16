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
    ./plex.nix
    ./transmission.nix
    ./cloudflared.nix
    ./vaultwarden.nix
    ./arr.nix
    ./tor.nix
    ./prowlarr.nix
    ./declarr.nix
    ./telegram-requests.nix
    ./herdr.nix
  ];

  # declarr: sync (WRITES) after a verified-zero --diff; backups in /srv/backup/arr/2026-11-15, restore: docs/arr-restore.md.
  mediabox.declarr.enable = true;
  mediabox.declarr.sync = true;

  # baravik.org (Belarusian) indexer, guest search, preferred over RuTracker (prowlarr.nix, declarr.nix).
  # Login is a separate step: mediabox.baravik.login = true after sops baravik-username/-password.
  mediabox.baravik.enable = true;

  # Telegram request bot (Searcharr). IDs are not secret. Add Olga's ID here when known.
  local.searcharr = {
    enable = true;
    allowedUserIds = [
      680033455 # Eugene
      657340029 # Olga
    ];
    # "Available in Plex" messages to the family group. If the log says "chat not found",
    # use -1005135740760 (supergroup form of the same id).
    notify = {
      enable = true;
      chatId = -5135740760;
      failures.enable = true; # nothing found / download failed / import stuck
    };
    status.enable = true; # /status: requests with live download state
    commandMenu.enable = true; # Telegram "/" menu (/users only in admins' private chats)
    # Users from Nix, requests from the arr searcharr-<id> tags. Rollback: declarative.enable = false.
    declarative.enable = true;
    users = {
      "680033455" = {
        username = "girl_has_n0_name";
        admin = true;
      };
      "657340029".username = "olgabrnvsk";
    };
  };

  # Tailnet: reach Plex/SSH over tailscale0 without opening them on LAN/WAN.
  dotfiles.tailscale = {
    enable = true;
    trustTailnet = true;
  };

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

  # /srv/backup must stay traversable (0755): service users (vaultwarden, ...) write their own
  # 07x0 subdirs. A hand-made `install -d -m 0700` once broke the vaultwarden backup.
  systemd.tmpfiles.rules = [
    "z /srv/backup 0755 root root -"
    "d /srv/backup/arr 0700 root root -"
  ];

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
      # Primary link: ethernet. Wi-Fi is a manual fallback (`nmcli con up wifi`).
      profiles.ethernet = {
        connection = {
          id = "ethernet";
          type = "ethernet";
          interface-name = "enp3s0";
          autoconnect = true;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
      profiles.wifi = {
        connection = {
          id = "wifi";
          type = "wifi";
          interface-name = "wlp2s0";
          autoconnect = false;
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
