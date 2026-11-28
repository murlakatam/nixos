# cliamp: terminal music player (prebuilt linux-amd64 binary). Radio by default; YouTube Music /
# Spotify credentials come from 1Password (op) at launch, never from Nix.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.dotfiles.music-players.cliamp;

  cliamp = pkgs.stdenv.mkDerivation rec {
    pname = "cliamp";
    version = "1.28.2";

    src = pkgs.fetchurl {
      url = "https://github.com/bjarneo/cliamp/releases/download/v${version}/cliamp-linux-amd64";
      hash = "sha256-w4wKj3HSGJDwwnHUmSfeAIHt54UPsrHxbR80wXYVXa4=";
    };

    dontUnpack = true;

    nativeBuildInputs = [pkgs.makeWrapper pkgs.autoPatchelfHook];
    buildInputs = [pkgs.alsa-lib pkgs.pipewire];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/cliamp
      chmod +x $out/bin/cliamp

      wrapProgram $out/bin/cliamp \
        --set ALSA_PLUGIN_DIR ${pkgs.pipewire}/lib/alsa-lib \
        --prefix PATH : ${lib.makeBinPath [pkgs.yt-dlp pkgs.ffmpeg]}
    '';

    meta = with lib; {
      description = "A terminal music player for your local files";
      homepage = "https://github.com/bjarneo/cliamp";
      license = licenses.mit;
      mainProgram = "cliamp";
    };
  };

  hasYtmusic = cfg.ytmusic.opClientIdPath != null && cfg.ytmusic.opClientSecretPath != null;
  hasSpotify = cfg.spotify.opClientIdPath != null;

  # Auto-select provider: spotify if configured, ytmusic if configured, else radio
  autoProvider =
    if hasSpotify
    then "spotify"
    else if hasYtmusic
    then "ytmusic"
    else "radio";

  # Simple TOML serializer for flat + one-level-deep sections
  tomlValue = v:
    if builtins.isBool v
    then
      (
        if v
        then "true"
        else "false"
      )
    else if builtins.isInt v || builtins.isFloat v
    then toString v
    else if builtins.isList v
    then "[${lib.concatMapStringsSep ", " tomlValue v}]"
    else ''"${v}"'';

  renderToml = attrs: let
    topLevel = lib.filterAttrs (_: v: !builtins.isAttrs v) attrs;
    sections = lib.filterAttrs (_: builtins.isAttrs) attrs;
  in
    lib.concatStringsSep "\n" (
      (lib.mapAttrsToList (k: v: "${k} = ${tomlValue v}") topLevel)
      ++ (lib.concatLists (lib.mapAttrsToList (
          k: v:
            ["\n[${k}]"]
            ++ (lib.mapAttrsToList (sk: sv: "${sk} = ${tomlValue sv}") v)
        )
        sections))
    );

  # Build the full settings with secret placeholders injected
  fullSettings = let
    base =
      cfg.settings
      // {
        provider = cfg.settings.provider or autoProvider;
      };
    withYtmusic =
      if hasYtmusic
      then
        base
        // {
          ytmusic =
            (base.ytmusic or {})
            // {
              client_id = "__YOUTUBE_CLIENT_ID__";
              client_secret = "__YOUTUBE_CLIENT_SECRET__";
            };
        }
      else base;
    withSpotify =
      if hasSpotify
      then
        withYtmusic
        // {
          spotify =
            (withYtmusic.spotify or {})
            // {
              client_id = "__SPOTIFY_CLIENT_ID__";
            };
        }
      else withYtmusic;
  in
    withSpotify;

  # Environment variables to set for op run (with op:// references)
  opRunEnvVars =
    lib.optionalString hasYtmusic ''YOUTUBE_CLIENT_ID="${cfg.ytmusic.opClientIdPath}" YOUTUBE_CLIENT_SECRET="${cfg.ytmusic.opClientSecretPath}" ''
    + lib.optionalString hasSpotify ''SPOTIFY_CLIENT_ID="${cfg.spotify.opClientIdPath}" '';

  # Sentinel check — pick the first configured secret's env var
  sentinelCheck =
    if hasYtmusic
    then ''[ -z "''${YOUTUBE_CLIENT_ID:-}" ]''
    else ''[ -z "''${SPOTIFY_CLIENT_ID:-}" ]'';

  # sed expressions to replace placeholders with resolved env vars
  sedExprs =
    lib.optionalString hasYtmusic ''
      SED_ARGS+=(-e "s|__YOUTUBE_CLIENT_ID__|$YOUTUBE_CLIENT_ID|g")
      SED_ARGS+=(-e "s|__YOUTUBE_CLIENT_SECRET__|$YOUTUBE_CLIENT_SECRET|g")
    ''
    + lib.optionalString hasSpotify ''
      SED_ARGS+=(-e "s|__SPOTIFY_CLIENT_ID__|$SPOTIFY_CLIENT_ID|g")
    '';

  needsSecretInjection = hasYtmusic || hasSpotify;

  cliampWrapper = pkgs.writeShellScriptBin "cliamp" ''
    ${lib.optionalString needsSecretInjection ''
      # Re-exec under op run to resolve secrets if not already set
      if ${sentinelCheck}; then
        ${opRunEnvVars}exec op run --no-masking -- "$0" "$@"
      fi
    ''}

    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/cliamp"

    ${lib.optionalString needsSecretInjection ''
      SED_ARGS=()
      ${sedExprs}
      ${pkgs.gnused}/bin/sed "''${SED_ARGS[@]}" "$CONFIG_DIR/config.base.toml" > "$CONFIG_DIR/config.toml"
    ''}

    exec ${cliamp}/bin/cliamp "$@"
  '';
in {
  options.dotfiles.music-players.enable = lib.mkEnableOption "cliamp, a terminal music player";

  options.dotfiles.music-players.cliamp = {
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Settings for ~/.config/cliamp/config.toml.
        Top-level keys become top-level TOML keys, nested attrsets become [section] headers.
        Example: { volume = 0; shuffle = false; visualizer = "Bars"; }
      '';
    };

    ytmusic = {
      opClientIdPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "1Password CLI path for the YouTube OAuth client ID";
      };

      opClientSecretPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "1Password CLI path for the YouTube OAuth client secret";
      };
    };

    spotify = {
      opClientIdPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "1Password CLI path for the Spotify client ID";
      };
    };
  };

  config = lib.mkIf config.dotfiles.music-players.enable {
    home.packages = [
      pkgs.ffmpeg
      pkgs.yt-dlp
      cliampWrapper
    ];

    # Write config template (secrets replaced at runtime by the wrapper)
    xdg.configFile."cliamp/config.base.toml".text = renderToml fullSettings + "\n";

    # If no secrets needed, write config.toml directly
    xdg.configFile."cliamp/config.toml" = lib.mkIf (!needsSecretInjection) {
      text = renderToml fullSettings + "\n";
    };
  };
}
