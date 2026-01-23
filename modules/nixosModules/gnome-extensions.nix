{
  pkgs,
  lib,
  config,
  ...
}: let
  batteryExtensionCfg = config.desktop.gnome.batteryExtension;

  # 1. Capture the original UUID so we can restore it after overriding
  basePkg = pkgs.gnomeExtensions.battery-health-charging;
  extUuid = basePkg.extensionUuid;

  # Helper: Patch metadata.json
  patchExt = ext:
    ext.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.jq];
      postPatch =
        (old.postPatch or "")
        + ''
          jq '.["shell-version"] += ["${lib.versions.major pkgs.gnome-shell.version}"]' metadata.json > t.json && mv t.json metadata.json
        '';
    });

  hibernateExt = patchExt pkgs.gnomeExtensions.hibernate-status-button;

  # 2. The Extension Patch
  batteryExt = basePkg.overrideAttrs (old: {
    # CRITICAL: Restore the extensionUuid so your filter doesn't delete it
    passthru = (old.passthru or {}) // {extensionUuid = extUuid;};

    postPatch =
      (old.postPatch or "")
      + ''
        # A. Fix the binary path in the driver
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl'

        # B. Fix the "Is Installed?" check
        # The extension looks for the policy file in /usr/share. We redirect it to NixOS path.
        substituteInPlace lib/driver.js \
          --replace-warn '/usr/share/polkit-1' \
                         '/run/current-system/sw/share/polkit-1'

        # C. Patch the helper script just in case (lobotomy)
        sed -i '/^    CHECKINSTALLATION)$/,/^        ;;$/{ s/check_installation/exit 0/ }' resources/batteryhealthchargingctl
      '';
  });

  # 3. The Helper Script (Binary)
  # using 'find' to avoid directory naming errors (CamelCase vs lowercase)
  batteryScript = pkgs.runCommand "batteryhealthchargingctl" {} ''
    mkdir -p $out/bin
    # Find the script dynamically inside the extension folder
    SCRIPT_PATH=$(find ${batteryExt} -name batteryhealthchargingctl -type f | head -n 1)
    ln -s "$SCRIPT_PATH" $out/bin/batteryhealthchargingctl
  '';

  # 4. CRITICAL MISSING PIECE: The Policy XML File
  # The extension checks specifically for the existence of this file.
  # Without this, the "Install Check" fails even if you have permissions.
  batteryPolicy = pkgs.writeTextFile {
    name = "battery-health-policy";
    destination = "/share/polkit-1/actions/org.freedesktop.policykit.batteryhealthcharging.setthreshold.policy";
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN" "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
      <policyconfig>
        <vendor>Battery Health Charging</vendor>
        <vendor_url>https://github.com/maniacx/Battery-Health-Charging</vendor_url>
        <action id="org.freedesktop.policykit.batteryhealthcharging.setthreshold">
          <description>Control battery thresholds</description>
          <message>No Authorization required to control battery thresholds.</message>
          <defaults>
            <allow_any>yes</allow_any>
            <allow_inactive>yes</allow_inactive>
            <allow_active>yes</allow_active>
          </defaults>
          <annotate key="org.freedesktop.policykit.exec.path">/run/current-system/sw/bin/batteryhealthchargingctl</annotate>
          <annotate key="org.freedesktop.policykit.batteryhealthcharging.setthreshold.polkit-rule.version">3.0.0</annotate>
        </action>
      </policyconfig>
    '';
  };

  allExtensions =
    [
      pkgs.gnomeExtensions.window-calls
      pkgs.gnomeExtensions.gpu-supergfxctl-switch
      hibernateExt
    ]
    ++ lib.optionals batteryExtensionCfg.enable [
      batteryExt
      batteryScript
      batteryPolicy # <--- Must be installed!
    ];
in {
  options.desktop.gnome.batteryExtension.enable = lib.mkEnableOption "Battery Health Charging Extension";

  config = {
    environment.systemPackages = allExtensions;

    programs.dconf.profiles.user.databases = [
      {
        lockAll = false;
        settings = lib.mkMerge [
          {
            "org/gnome/shell" = {
              disable-user-extensions = false;
              enabled-extensions = map (e: e.extensionUuid) (lib.filter (e: e ? extensionUuid) allExtensions);
            };
          }
          (lib.mkIf batteryExtensionCfg.enable {
            # Set both casings to be safe. "polkit-status" is often case-sensitive in dconf.
            "org/gnome/shell/extensions/battery-health-charging".polkit-status = "installed";
            "org/gnome/shell/extensions/Battery-Health-Charging".polkit-status = "installed";
          })
        ];
      }
    ];

    security.polkit.extraConfig = lib.mkIf batteryExtensionCfg.enable ''
      polkit.addRule(function(a, s) {
        if (a.id == "org.freedesktop.policykit.exec" &&
            a.lookup("program") == "/run/current-system/sw/bin/batteryhealthchargingctl" &&
            s.local && s.isInGroup("wheel")) return polkit.Result.YES;
      });
    '';
  };
}
