{
  config,
  lib,
  pkgs,
  ...
}: {
  # service that detects Mediatek Wifi failures on resume or timeout
  systemd.services.mt7925e-fix = {
    description = "Fix MT7925E WiFi after resume or timeout";
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
      "multi-user.target" # Also run at boot
    ];
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
      "network.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fix-mt7925e" ''
        # Check if the interface exists but is in a bad state
        if ip link show wlp99s0 &>/dev/null; then
          if ! ip link show wlp99s0 | grep -q "UP"; then
            echo "WiFi interface exists but is down, reloading driver..."
            ${pkgs.kmod}/bin/modprobe -r mt7925e
            sleep 3
            ${pkgs.kmod}/bin/modprobe mt7925e
            sleep 2
            ${pkgs.networkmanager}/bin/nmcli radio wifi off
            sleep 1
            ${pkgs.networkmanager}/bin/nmcli radio wifi on
          fi
        else
          echo "WiFi interface not found, reloading driver..."
          ${pkgs.kmod}/bin/modprobe -r mt7925e
          sleep 3
          ${pkgs.kmod}/bin/modprobe mt7925e
        fi
      '';
    };
  };

  # Create a systemd path unit to monitor for message timeouts in kernel log
  systemd.paths.mt7925e-monitor = {
    description = "Monitor for MT7925E message timeouts";
    wantedBy = ["multi-user.target"];
    pathConfig = {
      PathExists = "/sys/class/net/wlp99s0";
    };
  };

  systemd.services.mt7925e-monitor = {
    description = "Fix MT7925E when message timeouts are detected";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "monitor-mt7925e" ''
        if ${pkgs.procps}/bin/grep -q "mt7925e.*Message.*timeout" <(${pkgs.util-linux}/bin/dmesg | ${pkgs.gnugrep}/bin/grep -i mt7925e | ${pkgs.coreutils}/bin/tail -n 20); then
          echo "Detected MT7925E message timeout, reloading driver..."
          ${pkgs.kmod}/bin/modprobe -r mt7925e
          sleep 3
          ${pkgs.kmod}/bin/modprobe mt7925e
          sleep 2
          ${pkgs.networkmanager}/bin/nmcli radio wifi off
          sleep 1
          ${pkgs.networkmanager}/bin/nmcli radio wifi on
        fi
      '';
    };
  };

  # Add kernel module options that might help with stability
  # Disable PCIe Active State Power Management
  boot.extraModprobeConfig = ''
    options mt7925e disable_aspm=1
  '';
}
