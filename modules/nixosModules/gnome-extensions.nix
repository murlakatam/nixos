{pkgs, ...}: let
  # --- Configuration Variables ---
  # UUIDs found in: https://extensions.gnome.org/ or by running `gnome-extensions list`
  batteryUuid = "battery-health-charging@maniacx.github.com";
  windowCallsUuid = "window-calls@swyknox.github.com";
in {
  # 1. Install the Extensions
  environment.systemPackages = with pkgs; [
    gnomeExtensions.battery-health-charging
    gnomeExtensions.window-calls
    (pkgs.writeTextFile {
      name = "battery-health-charging-policy";
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
            <annotate key="org.freedesktop.policykit.exec.path">${pkgs.gnomeExtensions.battery-health-charging}/share/gnome-shell/extensions/${batteryUuid}/resources/batteryhealthchargingctl</annotate>
            <annotate key="org.freedesktop.policykit.batteryhealthcharging.polkit-rule.version">3.0.0</annotate>
          </action>
        </policyconfig>
      '';
    })
  ];

  # 3. Automatically Enable Extensions (Dconf)
  # This avoids you having to manually toggle them on in the "Extensions" app.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            batteryUuid
            windowCallsUuid
          ];
        };
      };
    }
  ];

  # Ensure Polkit is active (usually default, but good to be explicit)
  security.polkit.enable = true;
}
