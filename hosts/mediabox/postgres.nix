{pkgs, ...}: {
  # TEMPORARY archive of the NUC's `au` (schools) database. Nobody connects: localhost only, no
  # firewall change, no login passwords. Loaded once from a pg_dump (/srv/backup/nuc/).
  # To remove: drop this file and its import in config.nix, then delete /srv/backup/postgres and
  # /srv/backup/nuc (the data dir /var/lib/postgresql stays until removed by hand).
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    enableTCPIP = false;
    ensureDatabases = ["au"];
  };

  services.postgresqlBackup = {
    enable = true;
    databases = ["au"];
    location = "/srv/backup/postgres";
    startAt = "*-*-* 03:30:00";
  };
}
