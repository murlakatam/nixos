{...}: {
  # Tor client only: SOCKS5 on 127.0.0.1:9050 (module default), no relay/exit/onion services.
  # Used as a proxy by Radarr/Sonarr for indexers that need it.
  services.tor = {
    enable = true;
    client.enable = true;
    relay.enable = false;
    openFirewall = false;
  };
}
