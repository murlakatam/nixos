{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.desktop.gnome.batteryExtension;

  # 1. Define the correct, case-sensitive UUID and Schema
  # As confirmed by the docs you found:
  extUuid = "Battery-Health-Charging@maniacx.github.com";

  # 2. Patch the extension package
  batteryExt = pkgs.gnomeExtensions.battery-health-charging.overrideAttrs (old: {
    # Force the UUID to match upstream exactly so GNOME recognizes it
    passthru = (old.passthru or {}) // {extensionUuid = extUuid;};

    postPatch =
      (old.postPatch or "")
      + ''
        # Point the extension to the system-level binary and policy we are creating below
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl' \
          --replace-warn '/usr/share/polkit-1' \
                         '/run/current-system/sw/share/polkit-1'
      '';
  });

  # 3. Create the Wrapper Script
  # This fixes the "Unknown Command" error by pointing 'pkexec' to the right place
  batteryScript = pkgs.runCommand "batteryhealthchargingctl" {} ''
    mkdir -p $out/bin

    # Find the original script
    ORIG=$(find ${batteryExt} -name batteryhealthchargingctl -type f | head -n 1)

    # Copy and patch it to use NixOS's pkexec wrapper
    cp "$ORIG" $out/bin/batteryhealthchargingctl
    chmod +x $out/bin/batteryhealthchargingctl

    # The critical fix: /usr/bin/pkexec -> /run/wrappers/bin/pkexec
    sed -i 's|/usr/bin/pkexec|/run/wrappers/bin/pkexec|g' $out/bin/batteryhealthchargingctl
  '';

  # 4. Generate the Policy XML
  # This makes the "Install Check" pass because the file actually exists
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

  # 5. List of extensions to install
  allExtensions =
    [
      pkgs.gnomeExtensions.window-calls
      pkgs.gnomeExtensions.gpu-supergfxctl-switch
      # Add others here
    ]
    ++ lib.optionals cfg.enable [
      batteryExt
      batteryScript
      batteryPolicy
    ];
in {
  options.desktop.gnome.batteryExtension.enable = lib.mkEnableOption "Battery Health Charging Extension";

  config = {
    environment.systemPackages = allExtensions;

    # 6. Configure Dconf with the CORRECT Schema
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
          (lib.mkIf cfg.enable {
            # Use the EXACT CamelCase schema from the docs
            "org/gnome/shell/extensions/Battery-Health-Charging" = {
              polkit-status = "installed";
            };
          })
        ];
      }
    ];

    # 7. Polkit Rule (matches our wrapper path)
    security.polkit.extraConfig = lib.mkIf cfg.enable ''
      polkit.addRule(function(a, s) {
        if (a.id == "org.freedesktop.policykit.exec" &&
            a.lookup("program") == "/run/current-system/sw/bin/batteryhealthchargingctl" &&
            s.local && s.isInGroup("wheel")) return polkit.Result.YES;
      });
    '';
  };
}
