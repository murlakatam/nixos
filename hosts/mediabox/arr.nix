{lib, ...}: let
  # Hardlink imports: Transmission's download dir and the Plex library are both on the single
  # btrfs subvolume @media, so Radarr/Sonarr hardlink (torrent keeps seeding, no second copy).
  # They MUST use /srv/media/... paths (not the two separate /mnt/MediaLibrary1TB/* binds: EXDEV).
  # NOTE for the 4TB re-add (disko.nix): Transmission/ and Media/ must stay on ONE filesystem
  # and ONE subvolume, or hardlinks break.
  arrCommon = {
    group = "media";
    settings.auth = {
      method = "Forms"; # built-in login stays on
      required = "Enabled";
    };
  };
in {
  # Shared group: transmission writes downloads, radarr/sonarr hardlink + create library dirs.
  # protected_hardlinks=1 means the linker needs read+write on the source, hence g+w and umask 002.
  # Plex is not a member: it reads the library as "other" (files 644, dirs 755/2775).
  users.groups.media = {};
  users.users.transmission.extraGroups = ["media"];

  services.radarr = lib.recursiveUpdate arrCommon {
    enable = true;
    settings.server = {
      port = 7878;
      bindaddress = "*";
    };
  };
  services.sonarr = lib.recursiveUpdate arrCommon {
    enable = true;
    settings.server = {
      port = 8989;
      bindaddress = "*";
    };
  };

  # Created files/dirs are group-writable.
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
  # UI "Restart" exits cleanly; on-failure would leave the service down.
  systemd.services.radarr.serviceConfig.Restart = lib.mkForce "always";
  systemd.services.sonarr.serviceConfig.Restart = lib.mkForce "always";

  # LAN only on enp3s0; tailscale0 is already trusted. No tunnel hostname.
  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [7878 8989];

  # Existing dirs (non-recursive): group media, setgid, group-writable. Existing Plex files
  # stay root 644, still readable by plex.
  systemd.tmpfiles.rules = [
    "z /srv/media/Transmission/complete 2775 transmission media -"
    "z /srv/media/Media/Movies 2775 root media -"
    "z /srv/media/Media/Movies/Regular 2775 root media -"
    "z /srv/media/Media/Movies/Kids 2775 root media -"
    "z '/srv/media/Media/TV Shows' 2775 root media -"
    "z '/srv/media/Media/TV Shows/Regular' 2775 root media -"
    "z '/srv/media/Media/TV Shows/Kids' 2775 root media -"
  ];
}
