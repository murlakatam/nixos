# Public Pool (solo stratum pool, pkgs/public-pool) against the local bitcoind. The payout address
# is the miner's stratum username (Bitaxe config), never set here. Gated by nuc.publicPool.enable
# (set in config.nix): off while bitcoind syncs, because getblocktemplate fails during IBD.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nuc.publicPool;
  btc = config.services.bitcoind.main;
in {
  options.nuc.publicPool.enable = lib.mkEnableOption "Public Pool solo stratum pool on :3333";

  config = lib.mkIf cfg.enable {
    # Cookie readable by the bitcoind-main group (the datadir is 0770 bitcoind-main).
    services.bitcoind.main.extraConfig = "rpccookieperms=group";

    users.users.public-pool = {
      isSystemUser = true;
      group = "public-pool";
      extraGroups = [btc.group];
    };
    users.groups.public-pool = {};

    systemd.services.public-pool = {
      description = "Public Pool solo mining pool";
      after = ["bitcoind-main.service"];
      requires = ["bitcoind-main.service"];
      wantedBy = ["multi-user.target"];
      environment = {
        BITCOIN_RPC_URL = "http://127.0.0.1";
        BITCOIN_RPC_PORT = "8332";
        BITCOIN_RPC_TIMEOUT = "10000";
        BITCOIN_RPC_COOKIEFILE = "${btc.dataDir}/.cookie";
        BITCOIN_ZMQ_HOST = "tcp://127.0.0.1:28332";
        # API/UI binds 0.0.0.0 (hard-coded upstream) but the firewall keeps it closed: ssh -L 3334:localhost:3334 nuc.
        API_PORT = "3334";
        STRATUM_PORT = "3333";
        # Blank = no 1.5% dev fee output: the coinbase pays 100% to the miner's address.
        DEV_FEE_ADDRESS = "";
        NETWORK = "mainnet";
        API_SECURE = "false";
        POOL_IDENTIFIER = "nuc";
        EXTERNAL_SHARE_SUBMISSION_ENABLED = "false";
      };
      serviceConfig = {
        ExecStart = lib.getExe (pkgs.callPackage ../../pkgs/public-pool/package.nix {});
        User = "public-pool";
        Group = "public-pool";
        # The DB path ./DB/public-pool.sqlite is relative to the working directory.
        StateDirectory = "public-pool";
        WorkingDirectory = "/var/lib/public-pool";
        Restart = "on-failure";
        RestartSec = 10;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
        SystemCallArchitectures = "native";
        UMask = "0077";
        # MemoryDenyWriteExecute stays off: node's JIT needs W+X pages.
      };
    };

    # Stratum on the home LAN only. Not tailscale0 (SSH only there) and not the API port.
    networking.firewall.interfaces.eno1.allowedTCPPorts = [3333];
  };
}
