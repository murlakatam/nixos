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

    # Toshiba 1TB (ex-NUC): primary copy of the important data (photos, NUC archive, nightly
    # service backups). Subvolumes so the vault-backup read-only snapshots work.
    # Media stays on the backup HDD (@media, see config.nix): the 4 TB media-disk plan is shelved.
    vault = {
      type = "disk";
      device = "/dev/disk/by-id/ata-TOSHIBA_MQ01ABD100_Z664S2D2S";
      content = {
        type = "gpt";
        partitions.vault = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f" "-L" "vault"];
            mountpoint = "/srv/vault";
            mountOptions = ["compress=zstd" "noatime" "nofail"];
            subvolumes = let
              opts = ["compress=zstd" "noatime" "nofail"];
            in {
              "@photos" = {
                mountpoint = "/srv/vault/photos";
                mountOptions = opts;
              };
              "@nuc" = {
                mountpoint = "/srv/vault/nuc";
                mountOptions = opts;
              };
            };
          };
        };
      };
    };
  };
}
