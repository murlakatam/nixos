{
  pkgs,
  lib,
  config,
  ...
}: let
  # Helper: Patch metadata.json to support the current GNOME shell version
  patchGnomeExtension = ext:
    ext.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.jq];
      postPatch =
        (old.postPatch or "")
        + ''
          jq '.["shell-version"] += ["${lib.versions.major pkgs.gnome-shell.version}"]' metadata.json > tmp.json && mv tmp.json metadata.json
        '';
    });

  # 1. Patched Hibernate Extension
  hibernateExtension = patchGnomeExtension pkgs.gnomeExtensions.hibernate-status-button;

  # 2. Patched Battery Health Charging Extension
  # We consolidate all patching (driver paths and script logic) here to avoid redundancy.
  batteryExtension = pkgs.gnomeExtensions.battery-health-charging.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # Fix 1: Point driver.js to the NixOS system path for the executable
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl'

        # Fix 2: Patch the control script to bypass file-based Polkit checks
        # We modify the source script inside the extension directory directly
        sed -i '/^    CHECKINSTALLATION)$/,/^        ;;$/{
          s/check_installation/echo "NixOS: polkit configured declaratively"; exit 0/
        }' resources/batteryhealthchargingctl
      '';
  });

  # 3. Standalone Battery Script
  # Simply exposes the *already patched* script from the extension above to $PATH.
  batteryScript = pkgs.runCommand "batteryhealthchargingctl" {} ''
    mkdir -p $out/bin
    ln -s ${batteryExtension}/share/gnome-shell/extensions/Battery-Health-Charging@maniacx.github.com/resources/batteryhealthchargingctl $out/bin/batteryhealthchargingctl
  '';

  # Final list of extensions/packages to install
  myExtensions = [
    pkgs.gnomeExtensions.window-calls
    hibernateExtension
    batteryExtension
    batteryScript
  ];
in {
  # Fix: Removed redundant [ ] wrapper which created a nested list [[...]]
  environment.systemPackages = myExtensions;

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        /*
        local installation of GNOME Shell extensions (non-declaratively). When false, extension settings are locked via dconf
        */
        lockAll = false;
        settings = lib.mkMerge [
          {
            "org/gnome/shell" = {
              disable-user-extensions = false;
              # Filter out packages (like the script) that don't have UUIDs
              enabled-extensions = map (e: e.extensionUuid) (lib.filter (e: e ? extensionUuid) myExtensions);
            };
          }
          {
            "org/gnome/shell/extensions/Battery-Health-Charging" = {
              polkit-status = "installed";
            };
          }
        ];
      }
    ];
  };

  security.polkit = {
    enable = true;
    extraConfig = ''
      // Allow Battery Health Charging extension to set thresholds
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            action.lookup("program") == "/run/current-system/sw/bin/batteryhealthchargingctl" &&
            subject.local && subject.isInGroup("wheel"))
        {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
