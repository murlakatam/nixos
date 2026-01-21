{pkgs, ...}: let
  baseExtension = pkgs.gnomeExtensions.battery-health-charging;
  uuid = "battery-health-charging@maniacx.github.com";

  # 1. Extract the tool to a stable path
  batteryCtlTool = pkgs.runCommand "battery-health-ctl" {} ''
    mkdir -p $out/bin
    # Find the script dynamically to avoid build errors if paths change
    SCRIPT_PATH=$(find ${baseExtension} -name batteryhealthchargingctl -type f | head -n 1)
    if [ -z "$SCRIPT_PATH" ]; then
      echo "ERROR: Could not find batteryhealthchargingctl in ${baseExtension}"
      exit 1
    fi
    cp "$SCRIPT_PATH" $out/bin/batteryhealthchargingctl
    chmod +x $out/bin/batteryhealthchargingctl
  '';

  # 2. Patch the extension to use NixOS paths for BOTH the executable and the policy
  patchedExtension = baseExtension.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # Fix 1: Point to the binary we extracted above
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl'

        # Fix 2: Point to the NixOS Polkit location so the "is installed?" check passes
        # (This is why you were still seeing the popup)
        substituteInPlace lib/driver.js \
          --replace-warn '/usr/share/polkit-1/actions' \
                         '/run/current-system/sw/share/polkit-1/actions'
      '';
  });
in {
  environment.systemPackages = with pkgs; [
    patchedExtension
    batteryCtlTool
    gnomeExtensions.window-calls
  ];

  # 3. Allow the tool to run without password
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

  # 4. Force "installed" status in Dconf
  # We set this for both possible schema paths to be safe.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [uuid "window-calls@swyknox.github.com"];
        };

        # Correct lowercase schema path
        "org/gnome/shell/extensions/battery-health-charging" = {
          polkit-status = "installed";
        };

        # CamelCase path (fallback, just in case)
        "org/gnome/shell/extensions/Battery-Health-Charging" = {
          polkit-status = "installed";
        };
      };
    }
  ];

  security.polkit.enable = true;
}
