{
  lib,
  stdenv,
  fetchurl,
  writeShellScriptBin,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook,
  winetricks,
  wget,
  wine64,
  # Make these optional with defaults
  wine-gecko ? null,
  wine-mono ? null,
}: let
  # Use winetricks to get gecko/mono if the packages aren't available
  useWinetricksForDeps = wine-gecko == null || wine-mono == null;

  mt5Launcher = writeShellScriptBin "metatrader5" ''
    #!/bin/bash

    # Use absolute paths to wine binaries
    WINE="${wine64}/bin/wine64"
    WINEBOOT="${wine64}/bin/wineboot"
    WINECFG="${wine64}/bin/winecfg"
    WINETRICKS="${winetricks}/bin/winetricks"

    # Setup wine environment
    export WINEPREFIX="$HOME/.wine-metatrader5"
    export WINEARCH=win64
    export WINEDEBUG="+err"

    # For wine 10.0 compatibility
    export WINEESYNC=0
    export WINEFSYNC=0

    # Helper function for error handling
    handle_error() {
      echo "Error occurred. Please check your Wine installation."
      exit 1
    }

    # Clean up if requested
    if [ "$1" == "--clean" ] || [ "$1" == "--reinstall" ]; then
      echo "Removing existing Wine prefix..."
      rm -rf "$WINEPREFIX"
    fi

    # Test if wine is working before we do anything
    echo "Testing Wine installation..."
    $WINE --version || handle_error

    # Check for existing prefix or create new one
    if [ ! -d "$WINEPREFIX" ]; then
      echo "Setting up Wine prefix for MetaTrader 5..."

      # Initialize with minimal configuration first
      echo "Creating basic Wine prefix..."
      $WINEBOOT -i || handle_error

      echo "Waiting for Wine initialization..."
      sleep 5

      echo "Setting Windows version..."
      $WINECFG -v=win7 || handle_error

      # Basic setup completed, check if we have a functional prefix
      if [ -f "$WINEPREFIX/system.reg" ]; then
        echo "Wine prefix created successfully!"

        # Install MetaTrader 5
        TMP_DIR=$(mktemp -d)
        echo "Downloading MetaTrader 5 installer..."
        ${wget}/bin/wget -q -O "$TMP_DIR/mt5setup.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

        echo "Installing MetaTrader 5..."
        $WINE "$TMP_DIR/mt5setup.exe"

        rm -rf "$TMP_DIR"
      else
        echo "Failed to create Wine prefix. Please check your Wine installation."
        exit 1
      fi
    else
      # Launch MetaTrader 5
      PROGRAM_FILES="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
      if [ -d "$PROGRAM_FILES" ]; then
        echo "Launching MetaTrader 5..."
        $WINE "$PROGRAM_FILES/terminal64.exe"
      else
        echo "MetaTrader 5 installation not found. Reinstalling..."
        $0 --reinstall
      fi
    fi
  '';

  desktopItem = makeDesktopItem {
    name = "metatrader5";
    exec = "metatrader5";
    icon = "metatrader5";
    desktopName = "MetaTrader 5";
    genericName = "Trading Platform";
    categories = ["Finance"];
    comment = "MetaTrader 5 Trading Platform";
  };
in
  stdenv.mkDerivation {
    pname = "metatrader5";
    version = "5.0.0";

    dontUnpack = true;

    nativeBuildInputs = [copyDesktopItems wrapGAppsHook];

    # Only include non-null dependencies
    buildInputs =
      [wine64 winetricks wget]
      ++ lib.optional (wine-gecko != null) wine-gecko
      ++ lib.optional (wine-mono != null) wine-mono;

    desktopItems = [desktopItem];

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/share/icons/hicolor/256x256/apps

      ln -s ${mt5Launcher}/bin/metatrader5 $out/bin/metatrader5
      # Copy the local icon file
      cp ${./mt5.png} $out/share/icons/hicolor/256x256/apps/metatrader5.png
    '';

    meta = with lib; {
      description = "MetaTrader 5 Trading Platform";
      homepage = "https://www.metatrader5.com/";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = with maintainers; [];
    };
  }
