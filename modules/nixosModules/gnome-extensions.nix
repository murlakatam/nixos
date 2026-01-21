{pkgs, ...}: let
  # 1. Define the Base Extension and UUID
  baseExtension = pkgs.gnomeExtensions.battery-health-charging;
  uuid = "battery-health-charging@maniacx.github.com";

  # 2. Extract the helper script to a stable NixOS path
  # We use 'find' to locate the script dynamically inside the package structure
  batteryCtlTool = pkgs.runCommand "battery-health-ctl" {} ''
    mkdir -p $out/bin

    # Find the binary regardless of where it is hiding in the source
    SCRIPT_PATH=$(find ${baseExtension} -name batteryhealthchargingctl -type f | head -n 1)

    if [ -z "$SCRIPT_PATH" ]; then
      echo "ERROR: Could not find batteryhealthchargingctl in ${baseExtension}"
      exit 1
    fi

    cp "$SCRIPT_PATH" $out/bin/batteryhealthchargingctl
    chmod +x $out/bin/batteryhealthchargingctl
  '';

  # 3. Define the Polkit Policy XML
  # This creates the file that the extension looks for to verify "installation"
  batteryPolkitXml = pkgs.writeTextFile {
    name = "battery-health-polkit-xml";
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

  # 4. Patch the Extension to use the stable paths
  patchedExtension = baseExtension.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # Point the extension to the binary in /run/current-system/sw/bin
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' \
                         '/run/current-system/sw/bin/batteryhealthchargingctl'

        # Point the extension to the policy file in /run/current-system/sw/share
        # This fixes the "Please install polkit" popup check
        substituteInPlace lib/driver.js \
          --replace-warn '/usr/share/polkit-1/actions' \
                         '/run/current-system/sw/share/polkit-1/actions'
      '';
  });
in {
  # Install everything: The patched extension, the tool, and the XML policy
  environment.systemPackages = with pkgs; [
    patchedExtension
    batteryCtlTool
    batteryPolkitXml
    gnomeExtensions.window-calls
  ];

  # 5. Polkit Rule (JavaScript)
  # Allows the tool to run without password by matching the exact path
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.policykit.exec" &&
           action.lookup("program") == "/run/current-system/sw/bin/batteryhealthchargingctl") ||
          (action.id == "org.freedesktop.policykit.batteryhealthcharging.setthreshold"))
      {
        if (subject.local && subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      }
    });
  '';

  # 6. Dconf Configuration
  # We force the 'installed' status for both possible schema cases just to be safe
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [uuid "window-calls@swyknox.github.com"];
        };
        "org/gnome/shell/extensions/battery-health-charging" = {
          polkit-status = "installed";
        };
        "org/gnome/shell/extensions/Battery-Health-Charging" = {
          polkit-status = "installed";
        };
      };
    }
  ];

  security.polkit.enable = true;
}
