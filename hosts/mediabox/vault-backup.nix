{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mediabox.vaultBackup;

  # Why a script and not services.btrbk: both disks are plain top-level btrfs mounts
  # (/srv/backup also holds @media), and the data is mirrored with rsync between two
  # *different* filesystems. btrbk wants a subvolume layout on both sides and would need
  # the vault disk reorganised first. A ~100 line script is easier to audit.
  vault-backup = pkgs.writeShellApplication {
    name = "vault-backup";
    runtimeInputs = with pkgs; [coreutils util-linux btrfs-progs rsync findutils gawk gnugrep];
    text = ''
      VAULT=/srv/vault
      BACKUP=/srv/backup
      VAULT_MIRROR="$BACKUP/vault-mirror"    # copy of $VAULT, lives on the HDD
      SVC_MIRROR="$VAULT/backup-mirror"      # copy of the service backups, lives on the vault disk
      SVC_DIRS=(nuc vaultwarden arr postgres)
      KEEP_DAILY=${toString cfg.keepDaily}
      KEEP_WEEKLY=${toString cfg.keepWeekly}
      DRY=0
      [ "''${1:-}" = "--dry-run" ] && DRY=1
      [ $# -le 1 ] || { echo "usage: vault-backup [--dry-run]" >&2; exit 2; }

      die() { echo "vault-backup: ERROR: $*" >&2; exit 1; }

      # Refuse to run unless both disks are really mounted btrfs (and are different
      # filesystems), so a missing disk never fills the other one or the root fs.
      for m in "$VAULT" "$BACKUP"; do
        mountpoint -q "$m" || die "$m is not a mount point"
        [ "$(findmnt -no FSTYPE "$m")" = btrfs ] || die "$m is not btrfs"
      done
      [ "$(findmnt -no UUID "$VAULT")" != "$(findmnt -no UUID "$BACKUP")" ] \
        || die "$VAULT and $BACKUP are the same filesystem"

      size() { du -sb --one-file-system "$1" 2>/dev/null | cut -f1; }

      # snapshot_of <dir>: if <dir> is a btrfs subvolume, take a read-only snapshot in
      # <fs>/.snapshots and print the path to read from; otherwise print <dir> itself.
      snapshot_of() {
        local dir=$1 fs=$2 name stamp snap
        if ! btrfs subvolume show "$dir" >/dev/null 2>&1; then echo "$dir"; return; fi
        name=$(basename "$dir"); stamp=$(date +%Y%m%d); snap="$fs/.snapshots/$name.$stamp"
        if [ "$DRY" = 1 ]; then echo "would snapshot $dir -> $snap" >&2; echo "$dir"; return; fi
        mkdir -p "$fs/.snapshots"
        [ -e "$snap" ] || btrfs subvolume snapshot -r "$dir" "$snap" >/dev/null
        echo "$snap"
      }

      # prune <fs> <name>: keep the newest KEEP_DAILY snapshots plus the newest KEEP_WEEKLY
      # Sunday snapshots; delete the rest.
      prune() {
        local fs=$1 name=$2 s d keep=() n=0 w=0
        mapfile -t all < <(find "$fs/.snapshots" -maxdepth 1 -name "$name.[0-9]*" 2>/dev/null | sort -r)
        for s in "''${all[@]}"; do
          d=''${s##*.}
          if [ $n -lt "$KEEP_DAILY" ]; then keep+=("$s"); n=$((n+1)); continue; fi
          if [ "$(date -d "$d" +%u)" = 7 ] && [ $w -lt "$KEEP_WEEKLY" ]; then keep+=("$s"); w=$((w+1)); fi
        done
        for s in "''${all[@]}"; do
          printf '%s\n' "''${keep[@]}" | grep -qxF "$s" && continue
          if [ "$DRY" = 1 ]; then echo "would delete old snapshot $s"; else btrfs subvolume delete "$s" >/dev/null; fi
        done
      }

      # mirror <src> <dst> <exclude...>: rsync one directory. Never creates <dst>'s parents
      # outside the (already verified) mounts; skips @media and anything under /srv/media.
      mirror() {
        local src=$1 dst=$2; shift 2
        [ -d "$src" ] || { echo "skip $src (missing)"; return; }
        local excl=(--exclude=/@media --exclude=/.snapshots --exclude=/lost+found)
        for e in "$@"; do excl+=("--exclude=$e"); done
        if [ "$DRY" = 1 ]; then
          local changes
          changes=$(rsync -aHAXn --delete -i "''${excl[@]}" "$src/" "$dst/" 2>/dev/null | wc -l || true)
          echo "would sync $src ($(size "$src") bytes) -> $dst ($changes changes)"
        else
          mkdir -p "$dst"
          rsync -aHAX --delete "''${excl[@]}" "$src/" "$dst/"
          echo "synced $src -> $dst"
        fi
      }

      # 1. vault -> HDD: each top-level entry of the vault (except the mirror of the other
      #    side and snapshots), snapshotted first when it is a subvolume.
      for e in "$VAULT"/*; do
        [ -e "$e" ] || continue
        n=$(basename "$e")
        [ "$n" = backup-mirror ] && continue
        if [ -d "$e" ]; then
          src=$(snapshot_of "$e" "$VAULT")
          mirror "$src" "$VAULT_MIRROR/$n"
          prune "$VAULT" "$n"
        else
          if [ "$DRY" = 1 ]; then echo "would copy file $e"; else rsync -aHAX "$e" "$VAULT_MIRROR/"; fi
        fi
      done

      # 2. service backups on the HDD -> vault disk. Never @media, never vault-mirror.
      for n in "''${SVC_DIRS[@]}"; do
        src=$(snapshot_of "$BACKUP/$n" "$BACKUP")
        mirror "$src" "$SVC_MIRROR/$n"
        prune "$BACKUP" "$n"
      done

      [ "$DRY" = 1 ] && echo "dry run: nothing was changed" || echo "vault-backup: done"
    '';
  };
in {
  options.mediabox.vaultBackup = {
    enable = lib.mkEnableOption "two-disk mirror of the important data (vault <-> backup HDD)";
    keepDaily = lib.mkOption {
      type = lib.types.int;
      default = 7;
    };
    keepWeekly = lib.mkOption {
      type = lib.types.int;
      default = 4;
    };
    startAt = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 03:30:00";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [vault-backup];

    systemd.services.vault-backup = {
      description = "Mirror important data between /srv/vault and /srv/backup";
      startAt = cfg.startAt;
      unitConfig.OnFailure = "vault-backup-failed.service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe vault-backup;
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    # Visible failure: a priority-err journal line (journalctl -p err -u vault-backup-failed).
    # A Telegram notice can hook in here later.
    systemd.services.vault-backup-failed = {
      description = "vault-backup failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.util-linux}/bin/logger -p user.err -t vault-backup 'VAULT BACKUP FAILED: see journalctl -u vault-backup'";
      };
    };
  };
}
