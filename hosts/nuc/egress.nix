# NUC sandbox, LAN side: non-root processes (eugene's agents, nixbld fixed-output fetches, service users)
# cannot open new connections to private/LAN addresses. Internet egress stays open. Root daemons
# (tailscaled, nix-daemon, NetworkManager DHCP) are not filtered. Tailnet egress is blocked by the
# Tailscale policy (tag:nuc); this covers the home LAN.
#
# Switches the firewall backend from iptables to nftables: iptables cannot match "on-link IPv6"
# (LAN hosts like mediabox also have global IPv6 addresses in the ISP /64), nft can via `rt ip6 nexthop`.
# Only this table and the NixOS firewall tables are managed (flushRuleset stays off), so
# tailscaled's own rules are left alone.
_: {
  networking.nftables.enable = true;

  networking.nftables.tables.nuc-egress = {
    family = "inet";
    content = ''
      # Bitaxe LAN IP(s) for the NUCrypto stats poller (HTTP GET). Empty until the Bitaxe exists.
      set bitaxe_v4 {
        type ipv4_addr
      }

      chain output {
        type filter hook output priority filter; policy accept;
        ct state established,related accept
        oifname "lo" accept
        # Packets without a socket (kernel NDP, RSTs) have no skuid and skip this jump.
        meta skuid != 0 jump user_egress
      }

      chain user_egress {
        # DNS: tailscaled's MagicDNS (current resolv.conf), the router as fallback.
        ip daddr { 100.100.100.100, 192.168.0.1 } meta l4proto { tcp, udp } th dport 53 accept
        ip6 daddr fd7a:115c:a1e0::53 meta l4proto { tcp, udp } th dport 53 accept
        ip daddr @bitaxe_v4 tcp dport 80 accept

        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16 } counter reject
        ip6 daddr { fc00::/7, fe80::/10 } counter reject
        # Global IPv6 reached without a gateway = a LAN neighbour (routed traffic's nexthop is the router's fe80).
        ip6 daddr 2000::/3 rt ip6 nexthop != fe80::/10 counter reject
      }
    '';
  };
}
