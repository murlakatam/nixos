# NixOS Full Disk Encryption Migration Checklist

## System Information (Current)

| Item | Value |
|------|-------|
| Host | proartp16 |
| Disk | nvme0n1 (4TB CT4000T500SSD3) |
| NixOS Partition | nvme0n1p5 (1.7TB ext4) |
| Boot Partition | nvme0n1p1 (4.2GB vfat) |
| Windows | nvme0n1p3 (1.9TB) - PRESERVED |
| Current Usage | ~291GB |

## Prerequisites

- [ ] External drive available (minimum 350GB free)
- [ ] NixOS ISO downloaded (latest stable)
- [ ] USB drive for bootable installer
- [ ] Network credentials available (WiFi password)
- [ ] Dotfiles repo pushed to remote (github/gitlab)
- [ ] Strong LUKS passphrase prepared (minimum 20 characters recommended)

---

## Phase 1: Backup (Run from current system)

### 1.1 Mount External Drive
```bash
# Identify your external drive
lsblk

# Mount it
sudo mkdir -p /mnt/backup
sudo mount /dev/sdX1 /mnt/backup
```

### 1.2 Run Backup Script
```bash
cd ~/dotfiles/nixos/encryption
sudo ./backup.sh /mnt/backup
```

### 1.3 Verify Backup
- [ ] Check backup completed without errors
- [ ] Verify `/mnt/backup/nixos-fde-backup-*/root/home/eugene` exists
- [ ] Verify dotfiles are present: `ls /mnt/backup/nixos-fde-backup-*/root/home/eugene/dotfiles`
- [ ] Note the backup directory name: `___________________________________`

### 1.4 Push Dotfiles
```bash
cd ~/dotfiles/nixos
git add -A
git commit -m "Pre-encryption backup checkpoint"
git push
```

- [ ] Verified git push succeeded

### 1.5 Record Current UUIDs (for reference)
```bash
blkid /dev/nvme0n1p1  # Boot: ____________________
blkid /dev/nvme0n1p5  # Root: ____________________
```

---

## Phase 2: Create Bootable USB

### 2.1 Download NixOS ISO
```bash
# From another machine or before rebooting
wget https://channels.nixos.org/nixos-24.11/latest-nixos-gnome-x86_64-linux.iso
```

### 2.2 Write to USB
```bash
# CAREFUL: Replace sdY with your USB drive
sudo dd if=nixos-*.iso of=/dev/sdY bs=4M status=progress conv=fsync
```

- [ ] Bootable USB created

---

## Phase 3: Boot Installer & Encrypt

### 3.1 Boot from USB
- [ ] Restart laptop
- [ ] Enter BIOS/UEFI (usually F2 or Del)
- [ ] Select USB as boot device
- [ ] Boot into NixOS installer (GNOME live environment)

### 3.2 Connect to Network
```bash
# In terminal
nmtui
# Or use GNOME network settings
```

- [ ] Network connected

### 3.3 Encrypt NixOS Partition
```bash
# DESTRUCTIVE - ONLY AFTER BACKUP VERIFIED

# Format with LUKS2 encryption
sudo cryptsetup luksFormat --type luks2 /dev/nvme0n1p5

# You will be prompted for passphrase - USE STRONG PASSWORD
# Type YES to confirm

# Open the encrypted container
sudo cryptsetup luksOpen /dev/nvme0n1p5 cryptroot

# Format the decrypted volume
sudo mkfs.ext4 -L NixOS-Root /dev/mapper/cryptroot
```

- [ ] LUKS encryption completed
- [ ] Filesystem created inside encrypted container

### 3.4 Mount Filesystems
```bash
# Mount encrypted root
sudo mount /dev/mapper/cryptroot /mnt

# Mount existing boot partition
sudo mkdir /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot
```

- [ ] Filesystems mounted

### 3.5 Record New LUKS UUID
```bash
sudo blkid /dev/nvme0n1p5
# Note the UUID: ____________________________________
```

---

## Phase 4: Install NixOS

### 4.1 Generate Hardware Config
```bash
sudo nixos-generate-config --root /mnt
```

### 4.2 Clone Dotfiles
```bash
sudo mkdir -p /mnt/home/eugene
sudo chown 1000:100 /mnt/home/eugene

# Enter nix-shell with git
nix-shell -p git

# Clone your config
git clone https://github.com/YOUR_USERNAME/dotfiles.git /mnt/home/eugene/dotfiles
```

- [ ] Dotfiles cloned

### 4.3 Update Hardware Configuration
```bash
# Check generated config
cat /mnt/etc/nixos/hardware-configuration.nix

# It should contain boot.initrd.luks.devices section
# If not, copy from encryption/hardware-encrypted.nix.template
# and update the UUID
```

Edit `/mnt/home/eugene/dotfiles/nixos/hosts/proartp16/hardware.nix`:
- [ ] Updated `boot.initrd.luks.devices."cryptroot".device` with new LUKS UUID
- [ ] Added `allowDiscards = true` for SSD TRIM
- [ ] Changed `fileSystems."/"` device to `/dev/mapper/cryptroot`
- [ ] Added `aesni_intel` and `cryptd` to `boot.initrd.availableKernelModules`

### 4.4 Install NixOS
```bash
cd /mnt/home/eugene/dotfiles/nixos
sudo nixos-install --flake .#proartp16
```

- [ ] Installation completed
- [ ] Set root password when prompted

### 4.5 Reboot
```bash
sudo reboot
```

- [ ] Remove USB when prompted
- [ ] System boots to LUKS password prompt
- [ ] Password accepted, NixOS boots

---

## Phase 5: Restore Data

### 5.1 Mount Backup Drive
```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/sdX1 /mnt/backup
```

### 5.2 Restore Home Directory
```bash
# Find your backup
ls /mnt/backup/

# Restore home
sudo rsync -aAXHv /mnt/backup/nixos-fde-backup-*/root/home/ /home/

# Fix ownership
sudo chown -R eugene:users /home/eugene
```

- [ ] Home directory restored

### 5.3 Verify Restoration
- [ ] SSH keys present: `ls ~/.ssh/`
- [ ] Git config present: `cat ~/.gitconfig`
- [ ] Dotfiles intact: `ls ~/dotfiles/`

### 5.4 Rebuild NixOS
```bash
cd ~/dotfiles/nixos
sudo nixos-rebuild switch --flake .#proartp16
```

- [ ] Rebuild successful

---

## Phase 6: Verification

### 6.1 Verify Encryption Active
```bash
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT
```

Expected output:
```
nvme0n1              disk
├─nvme0n1p1          part  vfat    /boot
├─nvme0n1p5          part  crypto_LUKS
│ └─cryptroot        crypt ext4    /
...
```

- [ ] Encryption verified

### 6.2 Test Reboot
```bash
sudo reboot
```

- [ ] LUKS password prompt appears
- [ ] System boots successfully after password

### 6.3 Verify Windows Still Boots
- [ ] Reboot and select Windows from GRUB/systemd-boot
- [ ] Windows boots normally
- [ ] Reboot back to NixOS

### 6.4 Commit Updated Config
```bash
cd ~/dotfiles/nixos
git add -A
git commit -m "feat: enable LUKS full disk encryption"
git push
```

- [ ] Configuration committed

---

## Troubleshooting

### LUKS Password Not Accepted
- Check keyboard layout in initrd
- Try simpler password without special characters temporarily

### Boot Fails After Encryption
```bash
# Boot from USB again
sudo cryptsetup luksOpen /dev/nvme0n1p5 cryptroot
sudo mount /dev/mapper/cryptroot /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo nixos-enter
# Fix configuration, then:
nixos-rebuild boot --flake /home/eugene/dotfiles/nixos#proartp16
```

### Windows Boot Entry Missing
```bash
# From NixOS
sudo bootctl update
# Or regenerate GRUB if using GRUB
```

---

## Post-Migration

- [ ] Delete backup from external drive (after 1 week of stable operation)
- [ ] Store LUKS recovery passphrase securely (password manager)
- [ ] Consider adding backup LUKS key: `sudo cryptsetup luksAddKey /dev/nvme0n1p5`
