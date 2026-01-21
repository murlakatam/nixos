{
  config,
  pkgs,
  lib,
  ...
}: let
  # 1. Define the specific extension
  baseExtension = pkgs.gnomeExtensions.battery-health-charging;
  uuid = "battery-health-charging@maniacx.github.com";

  # 2. Extract the 'ctl' script ROBUSTLY
  # We use 'find' to locate the script because the directory structure
  # can vary between Nixpkgs versions.
  batteryCtlTool = pkgs.runCommand "battery-health-ctl" {} ''
    mkdir -p $out/bin

    # Find the file anywhere inside the extension directory
    SCRIPT_PATH=$(find ${baseExtension} -name batteryhealthchargingctl -type f | head -n 1)

    if [ -z "$SCRIPT_PATH" ]; then
      echo "ERROR: Could not find batteryhealthchargingctl in ${baseExtension}"
      exit 1
    fi

    cp "$SCRIPT_PATH" $out/bin/batteryhealthchargingctl
    chmod +x $out/bin/batteryhealthchargingctl
  '';

  # 3. Patch the extension to use the global system path
  patchedExtension = baseExtension.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # We substitute the path in driver.js to point to our extracted tool
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl'
      '';
  });
in {
  # Install the patched extension AND the standalone tool
  environment.systemPackages = with pkgs; [
    patchedExtension
    batteryCtlTool
    gnomeExtensions.window-calls
  ];

  # 4. Polkit Rule (Javascript)
  # Allows the binary at /run/current-system/sw/bin/... to run without sudo password
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          action.lookup("program") == "/run/current-system/sw/bin/batteryhealthchargingctl" &&
          subject.local && subject.isInGroup("wheel"))
      {
        return polkit.Result.YES;
      }
    });
  '';

  # 5. Dconf Settings to enable it automatically
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            uuid
            "window-calls@swyknox.github.com"
          ];
        };
        # Force "installed" status to suppress the UI error popup
        "org/gnome/shell/extensions/Battery-Health-Charging" = {
          polkit-status = "installed";
        };
      };
    }
  ];

  security.polkit.enable = true;
}
