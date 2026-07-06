{
  config,
  pkgs,
  lib,
  ...
}: let
  hostName = config.networking.hostName;

  # Root-only build helper. Takes NO arguments (so nothing can inject extra
  # nixos-rebuild flags), does NO git operations (commit happens unprivileged
  # in the user-facing wrapper). Its ONLY job is the privileged switch.
  #
  # The flake target and dir come from the caller's environment so this stays
  # host-agnostic; both are validated before use.
  # Shared body for both root helpers: no args, must be root, do the switch.
  rebuildRootBody = ''
    if [ "$#" -ne 0 ]; then
      echo "takes no arguments" >&2
      exit 64
    fi
    if [ "$(id -u)" -ne 0 ]; then
      echo "must be run as root via sudo" >&2
      exit 77
    fi
    exec nixos-rebuild switch --flake ".#${hostName}" --show-trace
  '';

  # AGENT path: root-only build helper. Takes NO arguments (so nothing can
  # inject extra nixos-rebuild flags), does NO git operations (commit happens
  # unprivileged in the user-facing wrapper). Sudo routes this to the STRICT
  # touch-only PAM service (no password fallback → fails closed).
  nixosRebuildAiRoot = pkgs.writeShellApplication {
    name = "nixos-rebuild-ai-root";
    runtimeInputs = [config.system.build.nixos-rebuild];
    text = rebuildRootBody;
  };

  # MANUAL path: identical build helper, but a SEPARATE binary so it gets its
  # own sudoers rule → its own PAM service that allows "touch OR password".
  # This is what your interactive `make system` / `rebuild` uses, so a dead or
  # absent YubiKey still lets you rebuild by typing your password.
  nixosRebuildManualRoot = pkgs.writeShellApplication {
    name = "nixos-rebuild-manual-root";
    runtimeInputs = [config.system.build.nixos-rebuild];
    text = rebuildRootBody;
  };
in {
  services = {
    # YubiKey required services and config
    pcscd.enable = true; # smartcard service for yubi key
    udev.packages = [pkgs.yubikey-personalization];
    #yubikey-agent.enable = true; #ssh agent specifically for yubi key
  };

  environment.systemPackages = with pkgs; [
    pam_u2f # yubikey with sudo
    yubioath-flutter # The Authenticator App (View 2FA codes on your desktop)
    yubikey-manager # The CLI tool (useful for scripting or quick "ykman" commands)
    yubikey-personalization # Low-level tool, sometimes needed for troubleshooting
    nixosRebuildAiRoot # agent rebuild helper (STRICT touch-only, see below)
    nixosRebuildManualRoot # manual rebuild helper (touch OR password, see below)
  ];

  # ─────────────────────────────────────────────────────────────────────────
  # Touch-gated privilege escalation for the rebuild helper.
  #
  # Goal: `nixos-rebuild-ai-root` can be run via sudo WITHOUT a Unix password,
  # but ONLY after a physical YubiKey touch (user presence). Everything else on
  # the system keeps its normal password-protected sudo.
  #
  # WHY NOT NOPASSWD: the NOPASSWD tag turns sudo authentication OFF entirely,
  # which bypasses the whole PAM auth stack — including pam_u2f. So it could
  # never require a touch. Instead we keep authentication ON (PASSWD) and, for
  # THIS command only, redirect sudo to a dedicated PAM service whose auth stack
  # is U2F-only (no pam_unix → no password prompt, pam_u2f required → touch or
  # fail). Confirmed by sudo's author: with NOPASSWD, pam_authenticate() is
  # never called.
  # ─────────────────────────────────────────────────────────────────────────

  # Global pam_u2f config. NOTE: `enable` is intentionally left false so U2F is
  # NOT bolted onto every PAM service — only the dedicated service below opts in
  # via `u2fAuth = true`. In this nixpkgs the per-service option is `u2fAuth`
  # (bool); the `control` is taken from this GLOBAL setting.
  security.pam.u2f = {
    control = "required"; # must succeed, no fallback → fails closed
    settings = {
      # Root-owned, immutable mapping. Enroll with:
      #   pamu2fcfg -u eugene -o pam://proartp16 -i pam://proartp16
      # then place the line at /etc/u2f_mappings (see README / comment below).
      authfile = "/etc/u2f_mappings";
      cue = true; # print "Please touch the device."
      userpresence = 1; # require a physical touch
      # Pin origin/appid to the host so enrollment is deterministic.
      origin = "pam://${hostName}";
      appid = "pam://${hostName}";
    };
  };

  # AGENT PAM service — STRICT touch-only, NO fallback.
  # Renders /etc/pam.d/nixos-rebuild-ai as: pam_u2f required, then pam_deny,
  # with no pam_unix in the auth phase → touch or fail closed.
  security.pam.services.nixos-rebuild-ai = {
    unixAuth = false; # remove pam_unix from the auth stack → no password
    u2fAuth = true; # add pam_u2f (required, from the global control above)
    rootOK = false; # don't let a root caller bypass the U2F check
  };

  # MANUAL PAM service — touch OR password.
  # pam_u2f is forced to `sufficient` for THIS service only (the global control
  # is `required`), and pam_unix is kept. Result auth stack:
  #   auth sufficient pam_u2f.so ...     ← a YubiKey tap succeeds immediately
  #   auth ...        pam_unix.so ...     ← no key / no touch? fall back to password
  # So a dead or absent key never blocks your interactive rebuild.
  security.pam.services.nixos-rebuild-manual = {
    unixAuth = true; # keep pam_unix → password fallback available
    u2fAuth = true; # add pam_u2f
    rootOK = false;
    rules.auth.u2f.control = lib.mkForce "sufficient";
  };

  # Scoped sudoers rules. Authentication stays ON (PASSWD, never NOPASSWD — that
  # would bypass PAM entirely and skip the touch check). Each command is routed
  # to its own PAM service, and never satisfied by a cached sudo timestamp
  # (timestamp_timeout=0 forces a fresh touch/password every time).
  #
  # We match on the STABLE profile path (/run/current-system/sw/bin/...), NOT the
  # raw /nix/store path: the store path changes on every rebuild (would go stale),
  # while the profile symlink is stable. Each wrapper invokes this exact same
  # absolute path, so the invoked string and the Cmnd_Alias match verbatim
  # regardless of how sudo canonicalizes symlinks. The trailing "" pins each to
  # zero arguments.
  security.sudo.extraConfig = ''
    Cmnd_Alias NIXOS_REBUILD_AI = /run/current-system/sw/bin/nixos-rebuild-ai-root ""
    Cmnd_Alias NIXOS_REBUILD_MANUAL = /run/current-system/sw/bin/nixos-rebuild-manual-root ""
    Defaults!NIXOS_REBUILD_AI pam_service=nixos-rebuild-ai
    Defaults!NIXOS_REBUILD_AI timestamp_timeout=0
    Defaults!NIXOS_REBUILD_MANUAL pam_service=nixos-rebuild-manual
    Defaults!NIXOS_REBUILD_MANUAL timestamp_timeout=0
    eugene ALL=(root) PASSWD: NIXOS_REBUILD_AI
    eugene ALL=(root) PASSWD: NIXOS_REBUILD_MANUAL
  '';
}
