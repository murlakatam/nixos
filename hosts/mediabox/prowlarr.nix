{
  config,
  lib,
  pkgs,
  ...
}: let
  baravik = config.mediabox.baravik;
  # Custom Cardigann definition (prowlarr-definitions/baravik.yml); the login block is spliced in
  # before "search:" only when baravik.login is on (guest search needs no account).
  baravikYml = let
    base = builtins.readFile ./prowlarr-definitions/baravik.yml;
    login = builtins.readFile ./prowlarr-definitions/baravik-login.yml;
  in
    pkgs.writeText "baravik.yml" (
      if baravik.login
      then builtins.replaceStrings ["\nsearch:\n"] ["\n${login}\nsearch:\n"] base
      else base
    );
in {
  options.mediabox.baravik = {
    enable = lib.mkEnableOption ''
      the baravik.org (Belarusian) indexer: custom Prowlarr definition, declarr indexer preferred over
      RuTracker, "Baravik" custom format, and 720p+1080p grouped in the "HD - 720p/1080p" profile'';
    login = lib.mkEnableOption ''
      logging in to baravik.org (needs sops keys baravik-username / baravik-password); off = guest
      search, which the site allows today'';
  };

  config = lib.mkMerge [
    (lib.mkIf baravik.enable {
      # Prowlarr reads <dataDir>/Definitions/Custom/*.yml at start. Copied as the service's own
      # DynamicUser in preStart (no root-owned paths under /var/lib/private), and the unit changes with
      # the file, so a new definition restarts Prowlarr. Disabling leaves the file; declarr then deletes
      # the indexer itself.
      systemd.services.prowlarr = {
        preStart = ''
          ${pkgs.coreutils}/bin/install -D -m 0644 ${baravikYml} /var/lib/prowlarr/Definitions/Custom/baravik.yml
        '';
        restartTriggers = [baravikYml];
      };
    })
    {
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
  ];
}
