{pkgs, ...}: {
  # Transmission 4 (reads the NUC's 3.00 resume/torrent files). NOT deployed until t16's copy is verified.
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openPeerPorts = true; # 51413 tcp+udp, same as the NUC
    openRPCPort = true; # 9091 tcp, LAN only via rpc-whitelist
    # JSON merged over settings (sops): {"rpc-username": "...", "rpc-password": "..."}; never printed.
    credentialsFile = "/run/secrets/transmission-credentials";
    settings = {
      download-dir = "/srv/media/Transmission/complete";
      incomplete-dir = "/srv/media/Transmission/incomplete";
      incomplete-dir-enabled = true;
      rpc-bind-address = "0.0.0.0";
      rpc-authentication-required = true;
      rpc-whitelist-enabled = true;
      rpc-whitelist = "127.0.0.1,::1,192.168.0.*";
      rpc-host-whitelist-enabled = false;
      # /transmission/rpc is public (Access bypass for the phone app): lock out brute force.
      anti-brute-force-enabled = true;
      anti-brute-force-threshold = 10;
      peer-port = 51413;
      umask = "002"; # group media must be able to write (hardlinks, protected_hardlinks)
    };
  };

  sops.secrets."transmission-credentials" = {
    owner = "transmission";
    sopsFile = ../../secrets/mediabox.yaml;
  };

  # Old NUC path (/mnt/MediaLibrary1TB/Transmission) so resume files keep matching: no recheck.
  fileSystems."/mnt/MediaLibrary1TB/Transmission" = {
    device = "/srv/media/Transmission";
    fsType = "none";
    options = ["bind" "nofail" "x-systemd.requires-mounts-for=/srv/media"];
  };

  systemd.services.transmission = {
    unitConfig = {
      RequiresMountsFor = ["/srv/media" "/mnt/MediaLibrary1TB/Transmission"];
      # Created by hand after copy verification + NUC state copy.
      ConditionPathExists = "/srv/media/Transmission/.transmission-ready";
    };
    serviceConfig.BindPaths = ["/srv/media/Transmission"];
  };

  systemd.tmpfiles.rules = ["d /srv/media/Transmission 2775 transmission transmission -"];
}
