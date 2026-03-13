function mount-NUC() {
    mkdir -p ~/mnt/NUC
    fusermount -u ~/mnt/NUC
    sshfs eugene@192.168.0.61:/mnt/MediaLibrary4TB ~/mnt/NUC -o reconnect,compression=yes,ServerAliveInterval=15,ServerAliveCountMax=3
}
