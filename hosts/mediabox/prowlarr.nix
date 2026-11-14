{lib, ...}: {
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
  systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [9696];
}
