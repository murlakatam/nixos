{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.mediabox.declarr;
  declarr = inputs.declarr.packages.${pkgs.stdenv.hostPlatform.system}.declarr;

  # sops keys (secrets/mediabox.yaml), each a single plain value; set from your own terminal
  # (see docs/mediabox-step17-declarr.md). The *-apikey ones are the CURRENT keys from config.xml.
  secretNames = {
    "arr-radarr-apikey" = "RADARR_APIKEY";
    "arr-sonarr-apikey" = "SONARR_APIKEY";
    "arr-prowlarr-apikey" = "PROWLARR_APIKEY";
    "transmission-username" = "TRANSMISSION_USER";
    "transmission-password" = "TRANSMISSION_PASS";
    "rutracker-username" = "RUTRACKER_USER";
    "rutracker-password" = "RUTRACKER_PASS";
    "plex-token" = "PLEX_TOKEN";
  };
  # declarr resolves "DECLARR_SECRET_FILE_<X>" to the contents of the file named by env var <that>.
  sec = key: "DECLARR_SECRET_FILE_${secretNames.${key}}";

  tags = ["flaresolverr"]; # unused tag, kept so v1 == live (removed in the v2 cleanup)

  plexFields = {
    host = "localhost";
    port = 32400;
    useSsl = false;
    authToken = sec "plex-token";
    signIn = "startOAuth";
    updateLibrary = true;
  };

  transmission = categoryField: {
    Transmission = {
      name = "Transmission";
      implementation = "Transmission";
      fields =
        {
          username = sec "transmission-username";
          password = sec "transmission-password";
        }
        // categoryField;
    };
  };

  # Absent top-level keys are left untouched by declarr; present ones are made EXACT (extras deleted).
  # Deliberately not declared: radarr/sonarr `indexer` (Prowlarr pushes them), qualityProfile,
  # customFormat, qualityDefinition (v1 scope).
  declarrConfig = {
    declarr.globalResolvePaths = [];

    radarr = {
      declarr = {
        type = "radarr";
        url = "http://127.0.0.1:7878";
      };
      config.host.apiKey = sec "arr-radarr-apikey";
      downloadClient = transmission {movieImportedCategory = "radarr";};
      rootFolder = [
        "/srv/media/Media/Movies/Regular"
        "/srv/media/Media/Movies/Kids"
      ];
      notification."Plex Media Server" = {
        name = "Plex Media Server";
        implementation = "PlexServer";
        fields = plexFields;
        onDownload = true;
        onUpgrade = true;
        onRename = true;
        onMovieDelete = true;
        onMovieFileDelete = true;
        onMovieFileDeleteForUpgrade = true;
      };
    };

    sonarr = {
      declarr = {
        type = "sonarr";
        url = "http://127.0.0.1:8989";
      };
      config.host.apiKey = sec "arr-sonarr-apikey";
      downloadClient = transmission {tvImportedCategory = "sonarr";};
      rootFolder = [
        "/srv/media/Media/TV Shows/Regular"
        "/srv/media/Media/TV Shows/Kids"
      ];
      notification."Plex Media Server" = {
        name = "Plex Media Server";
        implementation = "PlexServer";
        fields = plexFields;
        onDownload = true;
        onUpgrade = true;
        onImportComplete = true;
        onRename = true;
        onSeriesAdd = true;
        onSeriesDelete = true;
        onEpisodeFileDelete = true;
        onEpisodeFileDeleteForUpgrade = true;
      };
    };

    prowlarr = {
      declarr = {
        type = "prowlarr";
        url = "http://127.0.0.1:9696";
      };
      config.host.apiKey = sec "arr-prowlarr-apikey";
      inherit tags;
      downloadClient = {};
      appProfile.Standard = {};
      indexer."RuTracker.org" = {
        indexerName = "RuTracker.org";
        appProfileId = "Standard";
        tags = ["flare"];
        fields = {
          baseUrl = "https://rutracker.org/";
          username = sec "rutracker-username";
          password = sec "rutracker-password";
          useMagnetLinks = true;
          addRussianToTitle = true;
        };
      };
      applications = {
        Radarr = {
          name = "Radarr";
          implementation = "Radarr";
          fields.apiKey = sec "arr-radarr-apikey";
        };
        Sonarr = {
          name = "Sonarr";
          implementation = "Sonarr";
          fields.apiKey = sec "arr-sonarr-apikey";
        };
      };
      indexerProxy = {
        FlareSolverr = {
          name = "FlareSolverr";
          implementation = "FlareSolverr";
          tags = ["flare"];
          fields.requestTimeout = 180;
        };
        FlareSolverrViaTor = {
          name = "FlareSolverrViaTor";
          implementation = "FlareSolverr";
          tags = ["flaretor"];
          fields = {
            host = "http://localhost:8192";
            requestTimeout = 180;
          };
        };
        tor = {
          name = "tor";
          implementation = "Socks5";
          tags = ["tor"];
          fields = {
            host = "127.0.0.1";
            port = 9050;
          };
        };
      };
    };
  };

  configFile = pkgs.writeText "declarr.json" (builtins.toJSON declarrConfig);

  # Credentials are copied into $CREDENTIALS_DIRECTORY by systemd (root reads the sops files).
  envExports = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      k: v: ''export DECLARR_SECRET_FILE_${v}="$CREDENTIALS_DIRECTORY/${k}"''
    )
    secretNames);

  run = mode:
    pkgs.writeShellScript "declarr-${mode}" ''
      ${envExports}
      exec ${lib.getExe declarr} --${mode} ${configFile}
    '';
in {
  options.mediabox.declarr = {
    enable = lib.mkEnableOption "declarr oneshot (needs the sops keys in secretNames first)";
    sync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run --sync (WRITES, and deletes anything undeclared) instead of --diff (read-only).";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.mapAttrs (_: _: {}) secretNames;

    # Pin the API keys to the current values so existing links (Prowlarr apps, Searcharr) keep working.
    sops.templates = lib.genAttrs ["radarr" "sonarr" "prowlarr"] (n: {
      content = "${lib.toUpper n}__AUTH__APIKEY=${config.sops.placeholder."arr-${n}-apikey"}\n";
    });
    services.radarr.environmentFiles = [config.sops.templates.radarr.path];
    services.sonarr.environmentFiles = [config.sops.templates.sonarr.path];
    services.prowlarr.environmentFiles = [config.sops.templates.prowlarr.path];

    systemd.services.declarr = {
      description = "declarr: ${
        if cfg.sync
        then "sync"
        else "diff (read-only)"
      } Radarr/Sonarr/Prowlarr config";
      after = ["radarr.service" "sonarr.service" "prowlarr.service" "network.target"];
      wants = ["radarr.service" "sonarr.service" "prowlarr.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
        LoadCredential = lib.mapAttrsToList (k: _: "${k}:${config.sops.secrets.${k}.path}") secretNames;
        # arr APIs need a moment after start
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        ExecStart = run (
          if cfg.sync
          then "sync"
          else "diff"
        );
        # --diff exits 2 when the live config differs: that is a result, not a failure
        SuccessExitStatus = lib.mkIf (!cfg.sync) "2";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };
}
