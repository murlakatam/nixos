function mount-NUC() {
    fusermount -u /mnt/NUC
    mkdir -p /mnt/NUC
    sshfs eugene@192.168.0.52:/mnt/MediaLibrary4TB /mnt/NUC -o reconnect,compression=yes,ServerAliveInterval=15,ServerAliveCountMax=3
}
