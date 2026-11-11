{...}: {
  # Overlay VPN for reaching mediabox (Plex etc.) from outside behind CGNAT.
  # One-time login: `sudo tailscale up` on mediabox, open the printed URL.
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP 41641 for direct connections
    useRoutingFeatures = "none";
  };

  # Reach services over the tailnet (Plex 32400, SSH) without opening them on the LAN/WAN.
  networking.firewall.trustedInterfaces = ["tailscale0"];
}
