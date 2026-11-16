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
  # Prowlarr ONLY. Never declare `tags` for radarr/sonarr: the searcharr-<telegram id> tags there are
  # the only record of who requested what (Searcharr declarative mode, telegram-requests.nix), and a
  # declared list would make declarr delete them.
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
  # All six quality profiles, declared in full through qualityProfilePatch (fork): matched by NAME and
  # PUT to the existing id, so ids stay stable (movies/series reference qualityProfileId, Searcharr the
  # name) and nothing is ever deleted. The plain `qualityProfile` key is NOT used: it runs the profilarr
  # compiler, which expects profilarr YAML (needs formatDbRepo/stateDir) and would drop/replace profiles.
  # Items mirror the live API exactly (order = priority, lowest first); `allowed` names pick the tiers.
  q = id: name: source: resolution: extra: {
    quality = {inherit id name source resolution;} // extra;
    items = [];
  };
  rq = id: name: source: resolution: modifier: q id name source resolution {inherit modifier;};
  sq = id: name: source: resolution: q id name source resolution {};
  group = id: name: members: {inherit id name members;};

  radarrQualities = [
    (rq 0 "Unknown" "unknown" 0 "none")
    (rq 24 "WORKPRINT" "workprint" 0 "none")
    (rq 25 "CAM" "cam" 0 "none")
    (rq 26 "TELESYNC" "telesync" 0 "none")
    (rq 27 "TELECINE" "telecine" 0 "none")
    (rq 29 "REGIONAL" "dvd" 480 "regional")
    (rq 28 "DVDSCR" "dvd" 480 "screener")
    (rq 1 "SDTV" "tv" 480 "none")
    (rq 2 "DVD" "dvd" 0 "none")
    (rq 23 "DVD-R" "dvd" 480 "remux")
    (group 1000 "WEB 480p" [(rq 8 "WEBDL-480p" "webdl" 480 "none") (rq 12 "WEBRip-480p" "webrip" 480 "none")])
    (rq 20 "Bluray-480p" "bluray" 480 "none")
    (rq 21 "Bluray-576p" "bluray" 576 "none")
    (rq 4 "HDTV-720p" "tv" 720 "none")
    (group 1001 "WEB 720p" [(rq 5 "WEBDL-720p" "webdl" 720 "none") (rq 14 "WEBRip-720p" "webrip" 720 "none")])
    (rq 6 "Bluray-720p" "bluray" 720 "none")
    (rq 9 "HDTV-1080p" "tv" 1080 "none")
    (group 1002 "WEB 1080p" [(rq 3 "WEBDL-1080p" "webdl" 1080 "none") (rq 15 "WEBRip-1080p" "webrip" 1080 "none")])
    (rq 7 "Bluray-1080p" "bluray" 1080 "none")
    (rq 30 "Remux-1080p" "bluray" 1080 "remux")
    (rq 16 "HDTV-2160p" "tv" 2160 "none")
    (group 1003 "WEB 2160p" [(rq 18 "WEBDL-2160p" "webdl" 2160 "none") (rq 17 "WEBRip-2160p" "webrip" 2160 "none")])
    (rq 19 "Bluray-2160p" "bluray" 2160 "none")
    (rq 31 "Remux-2160p" "bluray" 2160 "remux")
    (rq 22 "BR-DISK" "bluray" 1080 "brdisk")
    (rq 10 "Raw-HD" "tv" 1080 "rawhd")
  ];
  sonarrQualities = [
    (sq 0 "Unknown" "unknown" 0)
    (sq 1 "SDTV" "television" 480)
    (group 1000 "WEB 480p" [(sq 12 "WEBRip-480p" "webRip" 480) (sq 8 "WEBDL-480p" "web" 480)])
    (sq 2 "DVD" "dvd" 480)
    (sq 13 "Bluray-480p" "bluray" 480)
    (sq 22 "Bluray-576p" "bluray" 576)
    (sq 4 "HDTV-720p" "television" 720)
    (sq 9 "HDTV-1080p" "television" 1080)
    (sq 10 "Raw-HD" "televisionRaw" 1080)
    (group 1001 "WEB 720p" [(sq 14 "WEBRip-720p" "webRip" 720) (sq 5 "WEBDL-720p" "web" 720)])
    (sq 6 "Bluray-720p" "bluray" 720)
    (group 1002 "WEB 1080p" [(sq 15 "WEBRip-1080p" "webRip" 1080) (sq 3 "WEBDL-1080p" "web" 1080)])
    (sq 7 "Bluray-1080p" "bluray" 1080)
    (sq 20 "Bluray-1080p Remux" "blurayRaw" 1080)
    (sq 16 "HDTV-2160p" "television" 2160)
    (group 1003 "WEB 2160p" [(sq 17 "WEBRip-2160p" "webRip" 2160) (sq 18 "WEBDL-2160p" "web" 2160)])
    (sq 19 "Bluray-2160p" "bluray" 2160)
    (sq 21 "Bluray-2160p Remux" "blurayRaw" 2160)
  ];
  # A group is allowed (with all its members) when its name is listed.
  mkItems = table: allowed:
    map (i: let
      on = lib.elem (i.name or i.quality.name) allowed;
    in
      if i ? members
      then {
        inherit (i) id name;
        items = map (m: m // {allowed = on;}) i.members;
        allowed = on;
      }
      else i // {allowed = on;})
    table;

  profileBase = {
    upgradeAllowed = false;
    minFormatScore = 0;
    cutoffFormatScore = 0;
    minUpgradeFormatScore = 1;
  };
  # Prefer HEVC/x265 within a tier only in the family profile.
  mkProfiles = table: extra: profiles:
    lib.mapAttrs (name: p:
      profileBase
      // extra
      // {
        inherit name;
        inherit (p) cutoff;
        items = mkItems table p.allowed;
        formatScores.HEVC =
          if name == "HD - 720p/1080p"
          then 100
          else 0;
      }
      // (p.extra or {}))
    profiles;

  # 480p fallback in the family profile (below 720p = lowest priority; cutoff and sizes unchanged).
  fallback480 = ["DVD" "WEB 480p" "Bluray-480p"];

  radarrProfiles = mkProfiles radarrQualities {language = original;} {
    "Any" = {
      cutoff = 20;
      allowed = ["WORKPRINT" "CAM" "TELESYNC" "TELECINE" "REGIONAL" "DVDSCR" "SDTV" "DVD" "DVD-R" "WEB 480p" "Bluray-480p" "Bluray-576p" "HDTV-720p" "WEB 720p" "Bluray-720p" "HDTV-1080p" "WEB 1080p" "Bluray-1080p" "Remux-1080p" "HDTV-2160p" "WEB 2160p" "Bluray-2160p" "Remux-2160p" "BR-DISK"];
    };
    "SD" = {
      cutoff = 20;
      allowed = ["WORKPRINT" "CAM" "TELESYNC" "TELECINE" "REGIONAL" "DVDSCR" "SDTV" "DVD" "WEB 480p" "Bluray-480p" "Bluray-576p"];
    };
    "HD-720p" = {
      cutoff = 6;
      allowed = ["HDTV-720p" "WEB 720p" "Bluray-720p"];
    };
    "HD-1080p" = {
      cutoff = 7;
      allowed = ["HDTV-1080p" "WEB 1080p" "Bluray-1080p" "Remux-1080p"];
    };
    "Ultra-HD" = {
      cutoff = 31;
      allowed = ["HDTV-2160p" "WEB 2160p" "Bluray-2160p" "Remux-2160p"];
    };
    "HD - 720p/1080p" = {
      cutoff = 6;
      allowed = fallback480 ++ ["HDTV-720p" "WEB 720p" "Bluray-720p" "HDTV-1080p" "WEB 1080p" "Bluray-1080p" "Remux-1080p"];
      # RuTracker releases are tagged Russian; "Original" rejected them all.
      extra.language = {
        id = -1;
        name = "Any";
      };
    };
  };
  original = {
    id = -2;
    name = "Original";
  };

  sonarrProfiles = mkProfiles sonarrQualities {} {
    "Any" = {
      cutoff = 1;
      allowed = ["SDTV" "WEB 480p" "DVD" "Bluray-480p" "Bluray-576p" "HDTV-720p" "HDTV-1080p" "WEB 720p" "Bluray-720p" "WEB 1080p" "Bluray-1080p"];
    };
    "SD" = {
      cutoff = 1;
      allowed = ["SDTV" "WEB 480p" "DVD" "Bluray-480p" "Bluray-576p"];
    };
    "HD-720p" = {
      cutoff = 4;
      allowed = ["HDTV-720p" "WEB 720p" "Bluray-720p"];
    };
    "HD-1080p" = {
      cutoff = 9;
      allowed = ["HDTV-1080p" "WEB 1080p" "Bluray-1080p"];
    };
    "Ultra-HD" = {
      cutoff = 16;
      allowed = ["HDTV-2160p" "WEB 2160p" "Bluray-2160p"];
    };
    "HD - 720p/1080p" = {
      cutoff = 4;
      allowed = fallback480 ++ ["HDTV-720p" "HDTV-1080p" "WEB 720p" "Bluray-720p" "WEB 1080p" "Bluray-1080p"];
    };
  };

  # Absent top-level keys are left untouched by declarr; present ones are made EXACT (extras deleted).
  # Deliberately not declared: radarr/sonarr `indexer` (Prowlarr pushes them), qualityProfile,
  # customFormat (profilarr-compiled, would delete the stock profiles). Sizes, the HEVC format and the six
  # quality profiles are declared via qualityDefinition / customFormatSet / qualityProfilePatch (fork,
  # non-destructive: a profile missing from the config is left alone, not deleted).
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
      qualityProfilePatch = radarrProfiles;
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
      qualityProfilePatch = sonarrProfiles;
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
