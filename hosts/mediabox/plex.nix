{pkgs, ...}: {
  services.plex = {
    enable = true;
    openFirewall = true;
    # NVENC/NVDEC: the module puts /run/opengl-driver/lib (nvidia libs) on LD_LIBRARY_PATH.
    # Hardware transcoding needs Plex Pass.
  };

  systemd.services.plex = {
    unitConfig = {
      RequiresMountsFor = ["/srv/media" "/mnt/MediaLibrary1TB/Media"];
      # Guard: never start against an unmounted disk or partial copy. The marker is created
      # by hand only after the media copy has been verified.
      ConditionPathExists = "/srv/media/Media/.plex-ready";
    };
    # Keep nixpkgs' KillSignal=SIGQUIT (Plex shuts its DBs down cleanly on it). Only the
    # bwrap FHS wrapper dies from SIGQUIT (core-dump), so the unit shows "failed" after a
    # stop: cosmetic. LimitCORE=0 avoids writing core files.
    serviceConfig = {
      LimitCORE = 0;
      # Let a big DB checkpoint finish on stop instead of being SIGKILLed.
      TimeoutStopSec = 300;
    };
  };

  # Plex keeps settings in Preferences.xml (not Nix). Enforce the ones we care about through
  # the local API each time Plex starts. The token is read at runtime and never logged.
  systemd.services.plex-settings = {
    description = "Apply declarative Plex server settings";
    wantedBy = ["plex.service"];
    after = ["plex.service"];
    unitConfig.ConditionPathExists = "/srv/media/Media/.plex-ready";
    path = [pkgs.curl pkgs.gnugrep pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      prefs="/var/lib/plex/Plex Media Server/Preferences.xml"
      for i in $(seq 1 60); do
        curl -fs -o /dev/null http://127.0.0.1:32400/identity && break
        sleep 2
      done
      token=$(grep -o 'PlexOnlineToken="[^"]*"' "$prefs" | cut -d'"' -f2)
      [ -n "$token" ] || { echo "no Plex token yet (server not claimed?); skipping"; exit 0; }
      # NVENC/NVDEC hardware transcoding (Plex Pass)
      # Tailscale address for outside access (CGNAT: no port forward possible)
      curl -fsS -X PUT -o /dev/null \
        "http://127.0.0.1:32400/:/prefs?HardwareAcceleratedCodecs=1&customConnections=http%3A%2F%2F100.117.219.75%3A32400&X-Plex-Token=$token"
      echo "applied Plex settings"
    '';
  };

  # Old NUC library path, so the migrated Plex database paths stay valid.
  # ONLY a bind of /srv/media/Media (the real NTFS disk is /mnt/toshiba).
  fileSystems."/mnt/MediaLibrary1TB/Media" = {
    device = "/srv/media/Media";
    fsType = "none";
    options = ["bind" "nofail" "x-systemd.requires-mounts-for=/srv/media"];
  };

  systemd.tmpfiles.rules = ["d /srv/media/Media 2775 root media -"];

  # Cutover rsync (run by hand): exclude Cache and Codecs.
}
