{config, ...}: {
  # Contents (env-file format):
  #   ADMIN_TOKEN='<argon2id PHC hash>'          (plain token: sops key vaultwarden-admin-token, for eugene)
  #   SMTP_HOST / SMTP_PORT / SMTP_SECURITY / SMTP_USERNAME / SMTP_PASSWORD / SMTP_FROM  (added once known;
  #   SMTP is required for the org "Account recovery administration" feature)
  sops.secrets."vaultwarden-env" = {};

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    backupDir = "/srv/backup/vaultwarden";
    environmentFile = config.sops.secrets."vaultwarden-env".path;
    config = {
      # Public hostname (cut over from the NUC).
      DOMAIN = "https://bw.murfly.me";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      # Accounts are created through admin-panel invites.
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;
      # WebSocket notifications are served on ROCKET_PORT by this version; no extra port.
    };
  };
}
