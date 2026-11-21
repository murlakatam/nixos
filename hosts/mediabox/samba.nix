# Samba on mediabox (replaces the NUC's). LAN (enp3s0) + tailscale0 only.
# Samba user "eugene" gets its password from sops (samba-eugene-password).
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.mediabox.samba.photos.enable = lib.mkEnableOption "read-only Photos share (merged /srv/photos, see photos.nix); needs the vault disk";

  config = {
    sops.secrets."samba-eugene-password".restartUnits = ["samba-eugene-passwd.service"];

    services.samba = {
      enable = true;
      openFirewall = false; # opened per-interface below
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "mediabox";
          "server role" = "standalone server";
          "map to guest" = "never";
          # No "bind interfaces only": smbd starts before tailscale0 has its IP and never binds it.
          # Access is limited by "hosts allow" (LAN, tailnet, localhost) plus the firewall instead,
          # which also keeps out the global IPv6 addresses on enp3s0.
          "hosts allow" = "192.168.0.0/24 100.64.0.0/10 fd7a:115c:a1e0::/48 127.0.0.1 ::1";
          "hosts deny" = "ALL";
          "disable netbios" = "yes"; # SMB over 445 only; discovery via wsdd/avahi
          "smb ports" = "445";
          "load printers" = "no";
          "printing" = "bsd";
          "printcap name" = "/dev/null";
          "disable spoolss" = "yes";
        };
        MediaLibrary = {
          comment = "media library";
          path = "/srv/media";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "eugene";
          "force group" = "media";
          "create mask" = "0664";
          "directory mask" = "2775";
        };
      };
    };

    # Read-only Photos share, merged into settings only when enabled.
    services.samba.settings.Photos = lib.mkIf config.mediabox.samba.photos.enable {
      comment = "photos";
      path = "/srv/photos";
      browseable = "yes";
      "read only" = "yes";
      "guest ok" = "no";
      "valid users" = "eugene";
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = false;
      interface = "enp3s0";
    };

    # tailscale0 is already trusted; open only on the LAN NIC.
    networking.firewall.interfaces.enp3s0 = {
      allowedTCPPorts = [445 5357]; # smb, wsdd
      allowedUDPPorts = [3702]; # wsdd
    };

    services.avahi.extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
      </service-group>
    '';

    # Set the Samba password for eugene from sops once smbd is up (and on every change).
    systemd.services.samba-eugene-passwd = {
      description = "Set Samba password for eugene from sops";
      wantedBy = ["multi-user.target"];
      after = ["samba-smbd.service"];
      requires = ["samba-smbd.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = "pw:${config.sops.secrets."samba-eugene-password".path}";
      };
      script = ''
        pw=$(cat "$CREDENTIALS_DIRECTORY/pw")
        printf '%s\n%s\n' "$pw" "$pw" | ${config.services.samba.package}/bin/smbpasswd -s -a eugene >/dev/null
      '';
    };
  };
}
