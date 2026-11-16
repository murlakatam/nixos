{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.searcharr;

  # Searcharr (Telegram bot -> Radarr/Sonarr). Long polling only (outbound), WAN is CGNAT.
  # Not in nixpkgs, so a small buildPythonApplication around a pinned upstream rev.
  # ./searcharr.patch (minimal, commented "NIX PATCH" hunks):
  #   1. Telegram user-ID allow-list gate (settings.searcharr_allowed_user_ids), fail-closed.
  #   2. SEARCHARR_DATA_DIR / SEARCHARR_SETTINGS env vars, since the source tree is read-only.
  #   3. Arr tag is always searcharr-<telegram user id> (digits, Radarr-safe).
  #   4. bot/notify.py: 127.0.0.1 webhook listener; arr import of a bot-requested item -> group message.
  #   5. lang/be-by.yml (plus notify_* keys in en-us.yml).
  #   6. notify.failures: add callbacks record requests (notify_requests table), history checker thread.
  #   7. status: /status command (bot/status.py), live state of tracked requests + Transmission speed.
  #   8. declarative (bot/declarative.py): users from local.searcharr.users, requests from arr tags.
  searcharr = pkgs.python3Packages.buildPythonApplication rec {
    pname = "searcharr";
    version = "3.4.0";
    format = "other";

    src = pkgs.fetchFromGitHub {
      owner = "toddrob99";
      repo = "searcharr";
      rev = "v${version}";
      hash = "sha256-j7B4AeG4nbGQERWjlnmOjsmGQjqFdA6dIEjWie2SRiI=";
    };
    patches = [./searcharr.patch];

    nativeBuildInputs = [pkgs.makeWrapper];
    dependencies = with pkgs.python3Packages; [
      python-telegram-bot
      apscheduler
      pyyaml
      arrow
      requests
    ];

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/searcharr $out/bin
      cp -r api bot config lang searcharr.py $out/share/searcharr/
      makeWrapper ${pkgs.python3.withPackages (_: dependencies)}/bin/python $out/bin/searcharr \
        --add-flags $out/share/searcharr/searcharr.py
      runHook postInstall
    '';
  };

  notify = cfg.notify;
  pyBool = b:
    if b
    then "True"
    else "False";

  pyList = l: "[" + lib.concatMapStringsSep ", " builtins.toJSON l + "]";

  # Secret-free settings (lives in the nix store). Secrets are read from systemd credentials.
  settings = pkgs.writeText "searcharr-settings.py" ''
    import os

    def _cred(name):
        with open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], name)) as f:
            return f.read().strip()

    searcharr_password = _cred("password")
    searcharr_admin_password = _cred("admin-password")
    searcharr_language = "be-by"
    searcharr_start_command_aliases = ["start"]
    searcharr_help_command_aliases = ["help"]
    searcharr_users_command_aliases = ["users"]
    # Only these Telegram user IDs may use the bot at all (see ./searcharr.patch). IDs are not secret.
    searcharr_allowed_user_ids = ${pyList cfg.allowedUserIds}

    tgram_token = _cred("token")

    sonarr_enabled = True
    sonarr_url = "http://127.0.0.1:8989"
    sonarr_api_key = _cred("sonarr-api-key")
    sonarr_quality_profile_id = ${pyList cfg.qualityProfiles}
    sonarr_add_monitored = True
    sonarr_search_on_add = True
    sonarr_tag_with_username = True  # tag is searcharr-<telegram user id> (./searcharr.patch), so Radarr-safe
    sonarr_forced_tags = []
    sonarr_allow_user_to_select_tags = False
    sonarr_user_selectable_tags = []
    sonarr_series_command_aliases = ["series"]
    sonarr_series_paths = []  # all root folders: user picks Regular or Kids
    sonarr_season_monitor_prompt = False

    radarr_enabled = True
    radarr_url = "http://127.0.0.1:7878"
    radarr_api_key = _cred("radarr-api-key")
    radarr_quality_profile_id = ${pyList cfg.qualityProfiles}
    radarr_add_monitored = True
    radarr_search_on_add = True
    radarr_tag_with_username = True  # tag is searcharr-<telegram user id> (./searcharr.patch), so Radarr-safe
    radarr_forced_tags = []
    radarr_allow_user_to_select_tags = False
    radarr_user_selectable_tags = []
    radarr_min_availability = "released"
    radarr_movie_command_aliases = ["movie"]
    radarr_movie_paths = []  # all root folders: user picks Regular or Kids

    # "available in Plex" group notifications (bot/notify.py; arr Webhook -> 127.0.0.1:<port>)
    searcharr_notify_enabled = ${pyBool notify.enable}
    searcharr_notify_port = ${toString notify.port}
    searcharr_notify_failures_enabled = ${pyBool (notify.enable && notify.failures.enable)}

    # /status: family requests (notify_requests table) with live download state
    searcharr_status_enabled = ${pyBool cfg.status.enable}
    searcharr_status_command_aliases = ["status"]
    ${lib.optionalString cfg.status.enable ''
      transmission_url = "http://127.0.0.1:9091/transmission/rpc"
      transmission_username = _cred("transmission-username")
      transmission_password = _cred("transmission-password")
    ''}
    # Declarative mode: users from Nix (users table ignored), requests from the searcharr-<id> arr tags
    searcharr_declarative = ${pyBool cfg.declarative.enable}
    ${lib.optionalString cfg.declarative.enable ''
      import json
      searcharr_users = json.loads(${builtins.toJSON (builtins.toJSON cfg.users)})
    ''}
    ${lib.optionalString notify.enable ''
      searcharr_notify_chat_id = ${toString notify.chatId}
      searcharr_notify_secret = _cred("webhook-secret")
    ''}
  '';

  secrets =
    {
      searcharr-token = "token";
      searcharr-password = "password";
      searcharr-admin-password = "admin-password";
      # Shared with declarr (declarr.nix), which pins these across reinstalls.
      arr-radarr-apikey = "radarr-api-key";
      arr-sonarr-apikey = "sonarr-api-key";
    }
    // lib.optionalAttrs notify.enable {
      # Shared with declarr.nix (X-Searcharr-Secret header of the arr Webhook connections).
      searcharr-webhook-secret = "webhook-secret";
    }
    // lib.optionalAttrs cfg.status.enable {
      # Shared with declarr.nix (Transmission download client); /status reads speed and ETA.
      transmission-username = "transmission-username";
      transmission-password = "transmission-password";
    };
in {
  options.local.searcharr = {
    enable = lib.mkEnableOption "Searcharr Telegram request bot (needs the sops keys below first)";
    allowedUserIds = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [];
      description = "Telegram user IDs allowed to use the bot. Empty = nobody (fail closed).";
    };
    qualityProfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["HD - 720p/1080p"];
      description = "Radarr/Sonarr quality profile names offered to requesters.";
    };
    notify = {
      enable = lib.mkEnableOption ''
        "available in Plex" messages in a Telegram group, naming who requested the item
        (needs sops key searcharr-webhook-secret; declarr.nix adds the arr Webhook connections)'';
      chatId = lib.mkOption {
        type = lib.types.int;
        description = "Telegram group chat id for the notifications (negative, e.g. -100...).";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8086;
        description = "Listener port, bound on 127.0.0.1 only.";
      };
      failures.enable = lib.mkEnableOption ''
        failure messages naming the requester (needs notify.enable): nothing found 30 min after a
        request, download failed (arr history, checked every 10 min), import stuck
        (ManualInteractionRequired webhook). Requests are tracked in /var/lib/searcharr/searcharr.db'';
    };
    status.enable = lib.mkEnableOption ''
      the /status command: requests made through the bot (since tracking began) with their state:
      searching, downloading (% / speed / time left, from Transmission) or ready in Plex.
      Reads the Transmission credentials (sops transmission-username / transmission-password)'';
    declarative.enable = lib.mkEnableOption ''
      declarative mode: users (and admins) come only from local.searcharr.users, and requests are
      read from the searcharr-<telegram id> tags in Radarr/Sonarr instead of the database. The
      database is then only a cache ("already sent" markers, Telegram names); deleting it loses
      nothing (the first check after that marks everything already due as sent, sends nothing)'';
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          username = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Telegram @username (without @), used for @-mentions when no name is known.";
          };
          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Display name in messages and /status (default: the user's Telegram name).";
          };
          admin = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Bot admin (/users shows the list; editing happens here).";
          };
        };
      });
      default = {};
      example = {
        "680033455" = {
          username = "someone";
          admin = true;
        };
      };
      description = "Bot users by Telegram user ID (used only with declarative.enable; must match allowedUserIds).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !cfg.declarative.enable
          || lib.sort lib.lessThan (lib.attrNames cfg.users)
          == lib.sort lib.lessThan (map toString cfg.allowedUserIds);
        message = "local.searcharr.users must list exactly the allowedUserIds when declarative.enable is set";
      }
    ];

    # sops keys (secrets/mediabox.yaml), each a single plain value; set from your own terminal:
    #   searcharr-token            BotFather token
    #   searcharr-password         shared user password (members send `/start <password>` in a DM with the bot)
    #   searcharr-admin-password   admin password (DM only, never in the group)
    #   arr-radarr-apikey / arr-sonarr-apikey   already declared by declarr.nix, nothing to add
    #   searcharr-webhook-secret   only with notify.enable: random string, e.g. `openssl rand -hex 32`
    sops.secrets = lib.mapAttrs (_: _: {}) secrets;

    systemd.services.searcharr = {
      description = "Searcharr Telegram request bot";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "radarr.service" "sonarr.service"];
      wants = ["network-online.target"];
      environment = {
        SEARCHARR_DATA_DIR = "/var/lib/searcharr";
        SEARCHARR_SETTINGS = "${settings}";
      };
      serviceConfig = {
        ExecStart = "${searcharr}/bin/searcharr --console-logging";
        Restart = "always";
        RestartSec = 10;
        DynamicUser = true;
        StateDirectory = "searcharr";
        WorkingDirectory = "/var/lib/searcharr";
        LoadCredential = lib.mapAttrsToList (k: v: "${v}:${config.sops.secrets.${k}.path}") secrets;

        # Hardening. Outbound to api.telegram.org + localhost arr; with notify.enable also listens on
        # 127.0.0.1:notify.port (AF_INET allowed, no IPAddressDeny, port > 1024 so no capability needed).
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
        CapabilityBoundingSet = "";
        UMask = "0077";
      };
    };
  };
}
