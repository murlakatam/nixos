# Bitcoin Core full node (nixpkgs services.bitcoind). Chainstate in the default dataDir on the
# NVMe; block files on the Toshiba drive (/srv/chain, see config.nix). No wallet, local RPC only.
{pkgs, ...}: let
  blocksDir = "/srv/chain/bitcoind";
in {
  services.bitcoind.main = {
    enable = true;
    # Initial sync: 12 GB lets most or all of the UTXO set stay cached, so it is rarely flushed
    # mid-sync. Lower to ~2000 once synced to give RAM back to the pool.
    dbCache = 12000;
    extraConfig = ''
      disablewallet=1
      blocksdir=${blocksDir}
      server=1
      # Outbound P2P only: no 8333 listener (tailscale0 is trusted, so the firewall would not stop it).
      listen=0
      # Cookie auth (dataDir/.cookie); no rpcuser/rpcpassword.
      rpcbind=127.0.0.1
      rpcallowip=127.0.0.1
      # Block notifications for the pool (slice 3).
      zmqpubrawblock=tcp://127.0.0.1:28332
    '';
  };

  systemd.services.bitcoind-main = {
    # /srv/chain is nofail: without the drive, never start (or write blocks to the root fs).
    unitConfig.RequiresMountsFor = [blocksDir];
    # Created here, after the mount, not via tmpfiles (which could run before it, on the root fs).
    serviceConfig.ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o bitcoind-main -g bitcoind-main ${blocksDir}";
  };
}
