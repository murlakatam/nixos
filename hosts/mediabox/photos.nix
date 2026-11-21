# Read-only merged photos view: photos (vault) + videos (backup HDD) under the same folder paths.
# Served by the Samba Photos share (samba.nix).
{pkgs, ...}: {
  environment.systemPackages = [pkgs.mergerfs];

  fileSystems."/srv/photos" = {
    device = "/srv/vault/photos:/srv/backup/photo-videos";
    fsType = "fuse.mergerfs";
    options = [
      "ro"
      "allow_other"
      "category.create=ff"
      "cache.files=off"
      "dropcacheonclose=true"
      "fsname=photos"
      "nofail"
      "x-systemd.requires-mounts-for=/srv/vault"
      "x-systemd.requires-mounts-for=/srv/backup"
    ];
  };

  systemd.tmpfiles.rules = ["d /srv/photos 0755 root root -"];

  mediabox.samba.photos.enable = true;
}
