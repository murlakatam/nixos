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

  pyList = l: "[" + lib.concatMapStringsSep ", " builtins.toJSON l + "]";

  # Secret-free settings (lives in the nix store). Secrets are read from systemd credentials.
  settings = pkgs.writeText "searcharr-settings.py" ''
    import os

    def _cred(name):
        with open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], name)) as f:
            return f.read().strip()

    searcharr_password = _cred("password")
    searcharr_admin_password = _cred("admin-password")
    searcharr_language = "en-us"
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
    sonarr_tag_with_username = True
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
    radarr_tag_with_username = True
    radarr_forced_tags = []
    radarr_allow_user_to_select_tags = False
    radarr_user_selectable_tags = []
    radarr_min_availability = "released"
    radarr_movie_command_aliases = ["movie"]
    radarr_movie_paths = []  # all root folders: user picks Regular or Kids
  '';

  secrets = {
    searcharr-token = "token";
    searcharr-password = "password";
    searcharr-admin-password = "admin-password";
    # Shared with declarr (declarr.nix), which pins these across reinstalls.
    arr-radarr-apikey = "radarr-api-key";
    arr-sonarr-apikey = "sonarr-api-key";
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
  };

  config = lib.mkIf cfg.enable {
    # sops keys (secrets/mediabox.yaml), each a single plain value; set from your own terminal:
    #   searcharr-token            BotFather token
    #   searcharr-password         shared user password (members send `/start <password>` in a DM with the bot)
    #   searcharr-admin-password   admin password (DM only, never in the group)
    #   arr-radarr-apikey / arr-sonarr-apikey   already declared by declarr.nix, nothing to add
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

        # Hardening. Outbound to api.telegram.org + localhost arr only.
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
