#!/usr/bin/env bash
#
# NixOS Full Disk Encryption Migration - Backup Script
# =====================================================
# Run this BEFORE attempting any encryption migration.
# Requires an external drive mounted for backup storage.
#
# Usage: ./backup.sh /mnt/backup
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check backup destination argument
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <backup-destination>"
    echo "Example: $0 /mnt/backup"
    echo ""
    echo "First mount your external drive:"
    echo "  sudo mount /dev/sdX1 /mnt/backup"
    exit 1
fi

BACKUP_DEST="$1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DEST}/nixos-fde-backup-${TIMESTAMP}"

# Verify backup destination is mounted and writable
if [[ ! -d "$BACKUP_DEST" ]]; then
    log_error "Backup destination '$BACKUP_DEST' does not exist"
    exit 1
fi

if ! touch "${BACKUP_DEST}/.write-test" 2>/dev/null; then
    log_error "Backup destination '$BACKUP_DEST' is not writable"
    exit 1
fi
rm -f "${BACKUP_DEST}/.write-test"

# Check available space (need at least 350GB for ~291GB of data + margin)
AVAILABLE_GB=$(df -BG "$BACKUP_DEST" | awk 'NR==2 {print $4}' | tr -d 'G')
USED_GB=$(df -BG / | awk 'NR==2 {print $3}' | tr -d 'G')
REQUIRED_GB=$((USED_GB + 50))  # Add 50GB margin

log_info "Backup destination: $BACKUP_DEST"
log_info "Available space: ${AVAILABLE_GB}GB"
log_info "Required space: ~${REQUIRED_GB}GB (${USED_GB}GB used + 50GB margin)"

if [[ $AVAILABLE_GB -lt $REQUIRED_GB ]]; then
    log_error "Not enough space on backup destination!"
    log_error "Need at least ${REQUIRED_GB}GB, only ${AVAILABLE_GB}GB available"
    exit 1
fi

log_success "Space check passed"

# Create backup directory structure
log_info "Creating backup directory: $BACKUP_DIR"
mkdir -p "${BACKUP_DIR}"/{root,boot,metadata}

# Step 1: Record system metadata
log_info "Recording system metadata..."

# Disk layout
lsblk -o NAME,UUID,FSTYPE,SIZE,MOUNTPOINT,LABEL > "${BACKUP_DIR}/metadata/lsblk.txt"
blkid > "${BACKUP_DIR}/metadata/blkid.txt"
fdisk -l > "${BACKUP_DIR}/metadata/fdisk.txt" 2>/dev/null || true

# Current NixOS generation
readlink -f /run/current-system > "${BACKUP_DIR}/metadata/current-generation.txt"

# Installed packages (for reference)
nix-store -qR /run/current-system > "${BACKUP_DIR}/metadata/installed-packages.txt" 2>/dev/null || true

# Boot configuration
cp /boot/loader/loader.conf "${BACKUP_DIR}/metadata/" 2>/dev/null || true
ls -la /boot/loader/entries/ > "${BACKUP_DIR}/metadata/boot-entries.txt" 2>/dev/null || true

log_success "Metadata recorded"

# Step 2: Backup boot partition
log_info "Backing up /boot partition..."
rsync -aAXHv --progress /boot/ "${BACKUP_DIR}/boot/"
log_success "Boot partition backed up"

# Step 3: Backup root filesystem (excluding virtual filesystems and backup destination)
log_info "Backing up root filesystem (this will take a while)..."
log_info "Excluding: /dev, /proc, /sys, /tmp, /run, /mnt, /media, /lost+found, /boot, /nix/store (can be rebuilt)"

# Note: We exclude /nix/store because it can be rebuilt from the configuration
# This significantly reduces backup size. If you want a complete backup, remove that exclusion.
rsync -aAXHv --progress \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found' \
    --exclude='/boot/*' \
    --exclude='/nix/store/*' \
    --exclude="$BACKUP_DEST" \
    / "${BACKUP_DIR}/root/"

log_success "Root filesystem backed up"

# Step 4: Create restore instructions
cat > "${BACKUP_DIR}/RESTORE-INSTRUCTIONS.md" << 'EOF'
# NixOS Backup Restore Instructions

## What's Included

- `root/` - Full root filesystem (excluding /nix/store)
- `boot/` - Boot partition contents
- `metadata/` - Disk layout and system information

## Restore Process

After installing NixOS with encryption enabled:

### 1. Restore Home Directory
```bash
sudo rsync -aAXHv /path/to/backup/root/home/ /home/
```

### 2. Restore Other User Data (if needed)
```bash
# Example: restore /var/lib for databases
sudo rsync -aAXHv /path/to/backup/root/var/lib/ /var/lib/

# Example: restore specific application data
sudo rsync -aAXHv /path/to/backup/root/etc/NetworkManager/ /etc/NetworkManager/
```

### 3. Fix Permissions
```bash
sudo chown -R eugene:users /home/eugene
```

### 4. Rebuild NixOS
```bash
cd ~/dotfiles/nixos
sudo nixos-rebuild switch --flake .#proartp16
```

## Important Notes

- `/nix/store` was NOT backed up - it will be rebuilt from your flake
- `/etc` is managed by NixOS - don't restore it wholesale
- Your dotfiles repo should be your source of truth for configuration
EOF

log_success "Restore instructions created"

# Step 5: Verify backup
log_info "Verifying backup..."
BACKUP_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
FILE_COUNT=$(find "${BACKUP_DIR}" -type f | wc -l)

echo ""
echo "========================================"
echo "           BACKUP COMPLETE"
echo "========================================"
echo ""
echo "Location: ${BACKUP_DIR}"
echo "Size: ${BACKUP_SIZE}"
echo "Files: ${FILE_COUNT}"
echo ""
echo "Contents:"
ls -lah "${BACKUP_DIR}/"
echo ""
log_success "Backup completed successfully!"
log_warn "IMPORTANT: Verify the backup before proceeding with encryption!"
log_info "Check that critical files exist in ${BACKUP_DIR}/root/home/"
