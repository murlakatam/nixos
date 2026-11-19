{
  # Only the 960 EVO. The Toshiba (sda) is deliberately not listed: disko never touches it.
  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_960_EVO_250GB_S3ESNX0J631519B";
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
              "@home" = {
                mountpoint = "/home";
                mountOptions = opts;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = opts;
              };
              "@var-log" = {
                mountpoint = "/var/log";
                mountOptions = opts;
              };
              # Later: a dedicated subvolume for minting data, e.g. "@minting" at /var/lib/minting.
            };
          };
        };
      };
    };
  };
}
