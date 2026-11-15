# Shared Tailscale module for every NixOS host (exported as nixosModules.tailscale).
# One-time login per host: `sudo tailscale up [--ssh]`, open the printed URL.
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.tailscale;
in {
  options.dotfiles.tailscale = {
    enable = lib.mkEnableOption "Tailscale overlay VPN";
    ssh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tailscale SSH (adds --ssh to up flags; no sshd needed).";
    };
    trustTailnet = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Trust tailscale0 in the firewall (all ports open to the tailnet).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true; # UDP 41641 for direct connections
      useRoutingFeatures = "none";
      extraUpFlags = lib.mkIf cfg.ssh ["--ssh"];
    };
    networking.firewall.trustedInterfaces = lib.mkIf cfg.trustTailnet ["tailscale0"];
  };
}
