{
  #config,
  pkgs,
  ...
}: {
  services = {
    # YubiKey required services and config
    pcscd.enable = true; # smartcard service for yubi key
    udev.packages = [pkgs.yubikey-personalization];
    #yubikey-agent.enable = true; #ssh agent specifically for yubi key
  };

  environment.systemPackages = with pkgs; [
    pam_u2f #yubikey with sudo
    yubioath-flutter # The Authenticator App (View 2FA codes on your desktop)
    yubikey-manager # The CLI tool (useful for scripting or quick "ykman" commands)
    yubikey-personalization #Low-level tool, sometimes needed for troubleshooting
  ];

  # security.pam = {
  #   sshAgentAuth.enable = true;
  #   u2f = {
  #     enable = true;
  #     settings = {
  #       cue = true;
  #       authfile = "${config.home.homeDirectory}/.config/Yubico/u2f_keys";
  #     };
  #   };
  #   services = {
  #     login.u2fAuth = true;
  #     sudo = {
  #       u2fAuth = true;
  #       sshAgentAuth = true; # Use SSH_AUTH_SOCK for sudo
  #     };
  #   };
  # };
}
