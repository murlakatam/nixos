{
  pkgs,
  lib,
  config,
  ...
}: let
  batteryExtensionCfg = config.desktop.gnome.batteryExtension;

  # 1. Capture the UUID so it isn't lost during override
  basePkg = pkgs.gnomeExtensions.battery-health-charging;
  extUuid = basePkg.extensionUuid;

  # Helper to patch extension metadata version
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

  # 2. Patch the Extension (Driver and Script)
  batteryExt = basePkg.overrideAttrs (old: {
    # CRITICAL: Preserve the UUID so the extension stays "Enabled"
    passthru = (old.passthru or {}) // {extensionUuid = extUuid;};

    postPatch =
      (old.postPatch or "")
      + ''
        # A. Patch Driver.js: Point to NixOS paths
        # We replace the path to the binary AND the path to the policy file
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl' \
          --replace-warn '/usr/share/polkit-1' \
                         '/run/current-system/sw/share/polkit-1'

        # B. Patch the Helper Script: Fix hardcoded /usr/bin/pkexec
        # This fixes the "Unknown Command" or crash when the script tries to escalate privileges
        sed -i 's|/usr/bin/pkexec|pkexec|g' resources/batteryhealthchargingctl
      '';
  });

  # 3. Create the System Binary
  # We use 'find' to dynamically locate the script inside the package
  batteryScript = pkgs.runCommand "batteryhealthchargingctl" {} ''
    mkdir -p $out/bin
    SCRIPT_PATH=$(find ${batteryExt} -name batteryhealthchargingctl -type f | head -n 1)
    ln -s "$SCRIPT_PATH" $out/bin/batteryhealthchargingctl
  '';

  # 4. Create the Policy XML File (The missing piece!)
  # The extension looks for this file to confirm installation.
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
      batteryPolicy # <--- REQUIRED
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
              # Filter ensures we only enable extensions that actually have UUIDs
              enabled-extensions = map (e: e.extensionUuid) (lib.filter (e: e ? extensionUuid) allExtensions);
            };
          }
          (lib.mkIf batteryExtensionCfg.enable {
            # Force "installed" status for both casing variants
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
