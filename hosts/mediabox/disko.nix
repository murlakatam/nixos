{
  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLW256HEHP-000H1_S340NA0K727234";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              subvolumes = let
                opts = ["compress=zstd" "noatime"];
              in {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = opts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = opts;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = opts;
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = opts;
                };
                "@lib" = {
                  mountpoint = "/var/lib";
                  mountOptions = opts;
                };
              };
            };
          };
        };
      };
    };

    # Seagate 2TB: SMART PASSED, no growth in 5/187/197/198 since the first survey.
    # History of 39,620 UDMA CRC errors and 61 old uncorrectables; SATA cable replaced
    # 2026-11-11. Fine as a backup target, not as the only copy of anything.
    backup = {
      type = "disk";
      device = "/dev/disk/by-id/ata-ST2000DM006-2DM164_Z4ZC5XYZ";
      content = {
        type = "gpt";
        partitions.backup = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f"];
            mountpoint = "/srv/backup";
            mountOptions = ["compress=zstd" "noatime" "nofail"];
          };
        };
      };
    };

    # media: no dedicated disk yet. Add one as a "media" disk like "backup" above, with the
    # new drive's by-id, btrfs, mountpoint /srv/media, options compress=zstd:1 noatime nofail,
    # then format just that disk with disko (not a full reinstall). Until then /srv/media is a
    # TEMPORARY subvolume on the backup HDD (see config.nix).
  };
}
