{ config, pkgs, lib, ... }:

let
  # Define the extension package once to ensure paths match exactly
  batteryExtension = pkgs.gnomeExtensions.battery-health-charging;
  
  # The helper script path inside the extension
  # Note: The UUID must match exactly what is in the /share path of the package
  extensionUuid = "battery-health-charging@maniacx.github.com";
  executablePath = "${batteryExtension}/share/gnome-shell/extensions/${extensionUuid}/resources/batteryhealthchargingctl";

  # Define the Polkit Policy strictly matching the installer's XML template
  batteryHealthPolkit = pkgs.writeTextFile {
    name = "battery-health-charging-polkit";
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
          
          <annotate key="org.freedesktop.policykit.exec.path">${executablePath}</annotate>
          
          <annotate key="org.freedesktop.policykit.batteryhealthcharging.setthreshold.polkit-rule.version">3.0.0</annotate>
        </action>
      </policyconfig>
    '';
  };

in
{
  # 1. Install Extensions + The Polkit Rule
  environment.systemPackages = with pkgs; [
    batteryExtension
    gnomeExtensions.window-calls
    batteryHealthPolkit
    # Add other extensions here
  ];

  # 2. Enable extensions by default (Dconf)
  programs.dconf.profiles.user.databases = [{
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          extensionUuid
          "window-calls@swyknox.github.com"
        ];
      };
    };
  }];

  # 3. Ensure Polkit is enabled
  security.polkit.enable = true;
}