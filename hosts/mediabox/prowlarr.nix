{
  config,
  lib,
  ...
}: {
  # Indexer manager for Radarr/Sonarr. LAN only on enp3s0 (tailscale0 is trusted).
  # Auth: if "Enabled" shows no first-run user setup (as with radarr/sonarr), bootstrap once with
  # DisabledForLocalAddresses, create the admin, then flip back to Enabled. Don't leave it disabled.
  services.prowlarr = {
    enable = true;
    settings = {
      auth = {
        method = "Forms";
        required = "Enabled";
      };
      server = {
        port = 9696;
        bindaddress = "*";
      };
    };
  };
  # UI "Restart" exits cleanly; on-failure would leave the service down.
  systemd.services.prowlarr.serviceConfig.Restart = lib.mkForce "always";

  # Cloudflare solver for Prowlarr: localhost only (module has no bind option; it defaults to 0.0.0.0).
  services.flaresolverr = {
    enable = true;
    port = 8191;
  };
  # Direct FlareSolverr: 127.0.0.1:8191, for indexers that only need the Cloudflare solver.
  # LOG_LEVEL=warning: at info it logs request bodies, including indexer login credentials.
  systemd.services.flaresolverr.environment = {
    HOST = "127.0.0.1";
    LOG_LEVEL = "warning";
  };

  # Second instance whose Chromium goes out via Tor (socks5 = remote DNS), for sites blocked by
  # the ISP, e.g. rutracker: 127.0.0.1:8192, no firewall port. Same hardened unit as the module's.
  # Prowlarr: FlareSolverr proxy "flare-tor" (http://127.0.0.1:8192) with tag flare-tor.
  systemd.services.flaresolverr-tor = {
    description = "FlareSolverr (via Tor)";
    after = ["network.target" "tor.service"];
    wants = ["tor.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      HOME = "/run/flaresolverr-tor";
      HOST = "127.0.0.1";
      PORT = "8192";
      LOG_LEVEL = "warning";
      PROXY_URL = "socks5://127.0.0.1:9050";
    };
    serviceConfig = {
      SyslogIdentifier = "flaresolverr-tor";
      Restart = "always";
      RestartSec = 5;
      Type = "simple";
      DynamicUser = true;
      UMask = "0077";
      RuntimeDirectory = "flaresolverr-tor";
      WorkingDirectory = "/run/flaresolverr-tor";
      ExecStart = lib.getExe config.services.flaresolverr.package;
      TimeoutStopSec = 30;

      # Same hardening as nixos/modules/services/misc/flaresolverr.nix
      LockPersonality = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      RestrictRealtime = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      RestrictNamespaces = ["net" "pid" "user"];
      CapabilityBoundingSet = [
        "~CAP_BLOCK_SUSPEND"
        "~CAP_BPF"
        "~CAP_CHOWN"
        "~CAP_IPC_LOCK"
        "~CAP_MKNOD"
        "~CAP_NET_ADMIN"
        "~CAP_NET_RAW"
        "~CAP_PERFMON"
        "~CAP_SYSLOG"
        "~CAP_SYS_ADMIN"
        "~CAP_SYS_BOOT"
        "~CAP_SYS_MODULE"
        "~CAP_SYS_PACCT"
        "~CAP_SYS_PTRACE"
        "~CAP_SYS_TIME"
        "~CAP_WAKE_ALARM"
      ];
      SystemCallFilter = [
        "~@chown"
        "~@clock"
        "~@cpu-emulation"
        "~@debug"
        "~@keyring"
        "~@memlock"
        "~@module"
        "~@obsolete"
        "~@pkey"
        "~@raw-io"
        "~@reboot"
        "~@setuid"
        "~@swap"
        "~@timer"
      ];
      SystemCallErrorNumber = "EPERM";
      SystemCallArchitectures = "native";
    };
  };

  # Workaround for the AU ISP (wbroadband) DNS block: its resolver returns a fake IP for
  # rutracker.org, but the block is DNS-only. Pin the real Cloudflare IPs (from DoH) so Prowlarr
  # and FlareSolverr reach it directly. If it stops working, re-check with
  # curl 'https://cloudflare-dns.com/dns-query?name=rutracker.org&type=A' -H accept:application/dns-json
  networking.hosts = {
    "104.21.32.39" = ["rutracker.org"];
    "172.67.182.196" = ["rutracker.org"];
  };

  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [9696];
}
