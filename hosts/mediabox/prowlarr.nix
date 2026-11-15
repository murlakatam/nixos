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
