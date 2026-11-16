{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.mediabox.declarr;
  notify = config.local.searcharr.notify;
  hookOn = notify.enable && config.local.searcharr.enable;
  declarr = inputs.declarr.packages.${pkgs.stdenv.hostPlatform.system}.declarr;

  # sops keys (secrets/mediabox.yaml), each a single plain value; set from your own terminal
  # (see docs/mediabox-step17-declarr.md). The *-apikey ones are the CURRENT keys from config.xml.
  secretNames =
    {
      "arr-radarr-apikey" = "RADARR_APIKEY";
      "arr-sonarr-apikey" = "SONARR_APIKEY";
      "arr-prowlarr-apikey" = "PROWLARR_APIKEY";
      "transmission-username" = "TRANSMISSION_USER";
      "transmission-password" = "TRANSMISSION_PASS";
      "rutracker-username" = "RUTRACKER_USER";
      "rutracker-password" = "RUTRACKER_PASS";
      "plex-token" = "PLEX_TOKEN";
    }
    // lib.optionalAttrs hookOn {
      # Shared with telegram-requests.nix (Searcharr checks it as X-Searcharr-Secret).
      "searcharr-webhook-secret" = "SEARCHARR_WEBHOOK_SECRET";
    };
  # declarr resolves "DECLARR_SECRET_FILE_<X>" to the contents of the file named by env var <that>.
  sec = key: "DECLARR_SECRET_FILE_${secretNames.${key}}";

  # Top-level tags list is declared (empty), so declarr deletes tags nothing uses and the config does not declare.
  tags = [];

  plexFields = {
    host = "localhost";
    port = 32400;
    useSsl = false;
    authToken = sec "plex-token";
    signIn = "startOAuth";
    updateLibrary = true;
  };

  # Searcharr "available in Plex" listener (telegram-requests.nix). Fires on first import only.
  # Radarr/Sonarr send a Test event to it when the connection is saved, so Searcharr must be up.
  searcharrHook = lib.optionalAttrs hookOn {
    "Searcharr" = {
      name = "Searcharr";
      implementation = "Webhook";
      fields = {
        url = "http://127.0.0.1:${toString notify.port}/hook";
        method = 1; # POST
        headers = [
          {
            key = "X-Searcharr-Secret";
            value = sec "searcharr-webhook-secret";
          }
        ];
      };
      onDownload = true;
      onUpgrade = false;
      # import stuck (failure messages, telegram-requests.nix notify.failures)
      onManualInteractionRequired = notify.failures.enable;
    };
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

  # Size caps in MB per minute of runtime (Radarr: film runtime, Sonarr: episode runtime).
  # Targets: 1080p film <= ~8 GB (68 MB/min * 120 min), 1080p episode <= ~2 GB (45 MB/min * 45 min);
  # 720p is half of that. Only the qualities in the "HD - 720p/1080p" profile are declared (names are
  # the API titles); 2160p/others are left as they are because no family profile can pick them.
  sizes = names: pref: max:
    lib.genAttrs names (_: {
      preferredSize = pref;
      maxSize = max;
    });
  radarrSizes =
    sizes ["HDTV-720p" "WEBDL-720p" "WEBRip-720p" "Bluray-720p"] 27 34
    // sizes ["HDTV-1080p" "WEBDL-1080p" "WEBRip-1080p" "Bluray-1080p" "Remux-1080p"] 55 68;
  sonarrSizes =
    sizes ["HDTV-720p" "WEBDL-720p" "WEBRip-720p" "Bluray-720p"] 17 22
    // sizes ["HDTV-1080p" "WEBDL-1080p" "WEBRip-1080p" "Bluray-1080p"] 35 45;

  # Prefer HEVC/x265 within the same quality tier; x264 stays allowed (minFormatScore stays 0).
  hevcFormat = {
    HEVC = {
      includeCustomFormatWhenRenaming = false;
      specifications = [
        {
          name = "x265/HEVC";
          implementation = "ReleaseTitleSpecification";
          negate = false;
          required = false;
          fields.value = "(?i)\\b(x265|h[ ._-]?265|hevc)\\b";
        }
      ];
    };
  };
  hevcProfile."HD - 720p/1080p" = {
    formatScores.HEVC = 100;
    minFormatScore = 0;
  };

  # Absent top-level keys are left untouched by declarr; present ones are made EXACT (extras deleted).
  # Deliberately not declared: radarr/sonarr `indexer` (Prowlarr pushes them), qualityProfile,
  # customFormat (profilarr-compiled, would delete the stock profiles). Sizes, the HEVC format and its score are
  # declared via qualityDefinition / customFormatSet / qualityProfilePatch (fork, non-destructive).
  declarrConfig = {
    declarr.globalResolvePaths = [];

    radarr = {
      declarr = {
        type = "radarr";
        url = "http://127.0.0.1:7878";
      };
      config.host.apiKey = sec "arr-radarr-apikey";
      qualityDefinition = radarrSizes;
      customFormatSet = hevcFormat;
      qualityProfilePatch = hevcProfile;
      downloadClient = transmission {movieImportedCategory = "radarr";};
      rootFolder = [
        "/srv/media/Media/Movies/Regular"
        "/srv/media/Media/Movies/Kids"
      ];
      notification =
        searcharrHook
        // {
          "Plex Media Server" = {
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
    };

    sonarr = {
      declarr = {
        type = "sonarr";
        url = "http://127.0.0.1:8989";
      };
      config.host.apiKey = sec "arr-sonarr-apikey";
      qualityDefinition = sonarrSizes;
      customFormatSet = hevcFormat;
      qualityProfilePatch = hevcProfile;
      downloadClient = transmission {tvImportedCategory = "sonarr";};
      rootFolder = [
        "/srv/media/Media/TV Shows/Regular"
        "/srv/media/Media/TV Shows/Kids"
      ];
      notification =
        searcharrHook
        // {
          "Plex Media Server" = {
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
      after = ["radarr.service" "sonarr.service" "prowlarr.service" "network.target"] ++ lib.optional hookOn "searcharr.service";
      wants = ["radarr.service" "sonarr.service" "prowlarr.service"] ++ lib.optional hookOn "searcharr.service";
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
