{pkgs, ...}: let
  # 1. Define your extensions here for easy management
  myExtensions = with pkgs.gnomeExtensions; [
    battery-health-charging
    window-calls
    # Add other extensions here, e.g.:
    # appindicator
    # dash-to-dock
  ];

  # 2. Define the Polkit Policy for Battery Health Charging
  # This creates the package that places the policy file in the correct read-only store path
  batteryHealthPolkit = pkgs.writeTextFile {
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
          <annotate key="org.freedesktop.policykit.exec.path">${pkgs.gnomeExtensions.battery-health-charging}/share/gnome-shell/extensions/battery-health-charging@maniacx.github.com/resources/batteryhealthchargingctl</annotate>
        </action>
      </policyconfig>
    '';
  };
in {
  # 3. Install Extensions and the Polkit Rule
  environment.systemPackages = with pkgs;
    [
      gnome-tweaks
      dconf-editor
      polkit # Toolkit for defining and handling the policy that allows unprivileged processes to speak to privileged processes
      polkit_gnome # PolicyKit authentication agent for GNOME
    ]
    ++ myExtensions ++ [batteryHealthPolkit];

  # 4. Enable extensions by default
  # This sets the global dconf profile to enable these extensions for all users.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          # Automatically enable the installed extensions
          enabled-extensions = [
            "battery-health-charging@maniacx.github.com"
            "window-calls@swyknox.github.com"
            # Add other UUIDs here if you add more extensions
          ];
        };
      };
    }
  ];

  # Ensure Polkit is enabled (usually is by default on GNOME)
  security.polkit.enable = true;
}
