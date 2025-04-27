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
    export WINEPREFIX="$HOME/.wine-metatrader5"
    # Changed to 32-bit architecture
    export WINEARCH=win32
    export WINEDLLOVERRIDES="mscoree=d"
    export WINEDEBUG="-all"

    if [ ! -d "$WINEPREFIX" ]; then
      echo "Setting up Wine prefix for MetaTrader 5..."
      wineboot -i
      winecfg -v=win10

      # Install required components
      ${
      if useWinetricksForDeps
      then ''
        # Install gecko and mono via winetricks if packages aren't available
        winetricks -q gecko mono
      ''
      else ""
    }
      winetricks -q msxml6 dotnet48 corefonts ddr=gdi

      # Download installers
      TMP_DIR=$(mktemp -d)
      echo "Downloading WebView2 Runtime..."
      ${wget}/bin/wget -q -O "$TMP_DIR/webview.exe" "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/c1336fd6-a2eb-4669-9b03-949fc70ace0e/MicrosoftEdgeWebview2Setup.exe"
      echo "Downloading MetaTrader 5 installer..."
      ${wget}/bin/wget -q -O "$TMP_DIR/mt5setup.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

      # Install WebView2 Runtime
      echo "Installing WebView2 Runtime..."
      wine "$TMP_DIR/webview.exe" /silent /install

      # Install MetaTrader 5
      echo "Installing MetaTrader 5..."
      wine "$TMP_DIR/mt5setup.exe"

      # Clean up
      rm -rf "$TMP_DIR"
    else
      # Launch MetaTrader 5
      PROGRAM_FILES="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
      if [ -d "$PROGRAM_FILES" ]; then
        # Changed to use terminal.exe (32-bit) instead of terminal64.exe
        wine "$PROGRAM_FILES/terminal.exe"
      else
        echo "MetaTrader 5 installation not found. Reinstalling..."
        # If can't find installation, try to install again
        TMP_DIR=$(mktemp -d)
        ${wget}/bin/wget -q -O "$TMP_DIR/mt5setup.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
        wine "$TMP_DIR/mt5setup.exe"
        rm -rf "$TMP_DIR"
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
