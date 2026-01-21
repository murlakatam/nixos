{
  pkgs,
  lib,
  config,
  ...
}: let
  batteryExtensionCfg = config.desktop.gnome.batteryExtension;

  # Helper: Patch metadata.json for version compatibility
  patchExt = ext:
    ext.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.jq];
      postPatch =
        (old.postPatch or "")
        + ''
          jq '.["shell-version"] += ["${lib.versions.major pkgs.gnome-shell.version}"]' metadata.json > t.json && mv t.json metadata.json
        '';
    });

  # Extensions
  hibernateExt = patchExt pkgs.gnomeExtensions.hibernate-status-button;

  batteryExt = pkgs.gnomeExtensions.battery-health-charging.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # Point to NixOS path
        substituteInPlace lib/driver.js \
          --replace-fail '/usr/local/bin/batteryhealthchargingctl-''${user}' '/run/current-system/sw/bin/batteryhealthchargingctl'
        # Bypass installation check
        sed -i '/^    CHECKINSTALLATION)$/,/^        ;;$/{ s/check_installation/exit 0/ }' resources/batteryhealthchargingctl
      '';
  });

  batteryScript = pkgs.runCommand "batteryhealthchargingctl" {} ''
    mkdir -p $out/bin
    ln -s ${batteryExt}/share/gnome-shell/extensions/Battery-Health-Charging@maniacx.github.com/resources/batteryhealthchargingctl $out/bin/
  '';

  # Final Package List
  allExtensions =
    [
      pkgs.gnomeExtensions.window-calls # GNOME extension to manage windows
      pkgs.gnomeExtensions.gpu-supergfxctl-switch # GNOME extension to integrate supergfxctl with GNOME Shell
      hibernateExt
    ]
    ++ lib.optionals batteryExtensionCfg.enable [batteryExt batteryScript];
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
