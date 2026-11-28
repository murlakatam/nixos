# GNOME desktop via dconf: terminal, custom keybindings, rofi launcher, small prefs and the
# mutter KMS-thread fix.
#
# This module is the ONLY writer of GNOME's custom-keybindings list (one dconf array, so two
# writers would fight). Hosts add their own binds through `customKeybindings`; herdr's
# WM-level binds (programs.herdr.wmKeybindings, F4 / Super+/) are picked up when that option
# exists. Super+space goes to rofi, so layout switching moves to Alt+Shift.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.gnome;

  # env -u WAYLAND_DISPLAY: rofi runs under Xwayland, its native Wayland mode misbehaves on GNOME.
  rofi = pkgs.writeShellScriptBin "rofi" ''
    exec env -u WAYLAND_DISPLAY ${pkgs.rofi}/bin/rofi -terminal ${cfg.terminal} -normal-window -theme "Arc-Dark" "$@"
  '';

  builtinBindings =
    {
      launchTerminal = {
        name = "Launch Terminal";
        key = "<Primary><Alt>t";
        command = cfg.terminal;
      };
    }
    // lib.optionalAttrs cfg.rofi.enable {
      launchAppSearch = {
        name = "Launch Rofi App Search";
        key = "<Super>space";
        command = ''rofi -show combi -combi-modi "window,drun,run"'';
      };
    };

  # Static binds first, herdr binds last (keeps the list order the work host already has).
  bindings =
    lib.mapAttrsToList (id: b: b // {inherit id;}) (builtinBindings // cfg.customKeybindings)
    ++ map (b: {inherit (b) id name key command;}) (config.programs.herdr.wmKeybindings or []);

  slot = id: "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${id}";
in {
  options.dotfiles.gnome = {
    enable = lib.mkEnableOption "GNOME dconf settings and custom keybindings";
    terminal = lib.mkOption {
      type = lib.types.str;
      description = "Terminal command: GNOME's default terminal, Ctrl+Alt+T and rofi's -terminal.";
    };
    rofi.enable = lib.mkEnableOption "rofi launcher on Super+space";
    customKeybindings = lib.mkOption {
      default = {};
      description = "Extra GNOME custom keybindings; the attr name is the dconf slot id.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {type = lib.types.str;};
          key = lib.mkOption {
            type = lib.types.str;
            description = "GNOME key spec, e.g. \"<Super>j\".";
          };
          command = lib.mkOption {type = lib.types.str;};
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional cfg.rofi.enable rofi;

    # mutter 46+ runs its KMS thread realtime; if it blocks past RLIMIT_RTTIME the kernel
    # SIGKILLs gnome-shell and the Wayland session dies (seen mid OBS screencast).
    systemd.user.sessionVariables.MUTTER_DEBUG_KMS_THREAD_TYPE = "user";

    dconf.settings =
      {
        "org/gnome/desktop/applications/terminal".exec = cfg.terminal;
        "org/gnome/mutter".center-new-windows = true;
        "org/gnome/desktop/notifications".show-in-lock-screen = false;
        # Geolocation flips the zone away from the TZ the session pins.
        "org/gnome/desktop/datetime".automatic-timezone = false;
        "org/gnome/shell/keybindings".show-screenshot-ui = ["<Shift><Super>s"];
        "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings =
          map (b: "/${slot b.id}/") bindings;
      }
      // lib.optionalAttrs cfg.rofi.enable {
        # Free <Super>space for rofi; Alt+Shift toggles layouts instead.
        "org/gnome/desktop/wm/keybindings" = {
          switch-input-source = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
          switch-input-source-backward = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
        };
        "org/gnome/desktop/input-sources".xkb-options = ["grp:alt_shift_toggle"];
      }
      // lib.listToAttrs (map (b:
        lib.nameValuePair (slot b.id) {
          inherit (b) name command;
          binding = b.key;
        })
      bindings);
  };
}
