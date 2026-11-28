# VM test: the NUC's bitcoind.nix + egress.nix + public-pool.nix on regtest. The pool (non-root, so
# under nuc-egress) reads the group cookie, reaches RPC over loopback and answers stratum on 3333.
{testers}:
testers.runNixOSTest {
  name = "nuc-public-pool";
  nodes.machine = {
    lib,
    pkgs,
    ...
  }: {
    imports = [./bitcoind.nix ./egress.nix ./public-pool.nix];
    nuc.publicPool.enable = true;
    virtualisation.memorySize = 2048;
    environment.systemPackages = [pkgs.jq];
    # Same bitcoin.conf, but every real line lands in a [regtest] section (rpcbind etc. are
    # rejected outside one on a non-main chain); RPC kept on the mainnet port the pool uses.
    services.bitcoind.main.extraConfig = lib.mkBefore ''
      regtest=1
      [regtest]
      rpcport=8332
    '';
    systemd.services.public-pool = {
      environment = {
        NETWORK = lib.mkForce "regtest";
        BITCOIN_RPC_COOKIEFILE = lib.mkForce "/var/lib/bitcoind-main/regtest/.cookie";
      };
      # Started by the script after blocks exist (a fresh regtest chain is in IBD).
      wantedBy = lib.mkForce [];
    };
  };

  testScript = ''
    cli = "bitcoin-cli -regtest -rpcport=8332 -datadir=/var/lib/bitcoind-main"
    machine.wait_for_unit("bitcoind-main.service")
    machine.wait_until_succeeds(f"{cli} getblockcount")
    machine.succeed("stat -c %a /var/lib/bitcoind-main/regtest/.cookie | grep -qx 640")
    # Mainnet's cookie sits in the 0770 datadir itself; regtest/ is created 0700, so open it like that.
    machine.succeed("stat -c %a /var/lib/bitcoind-main | grep -qx 770")
    machine.succeed("chmod 0750 /var/lib/bitcoind-main/regtest")
    machine.succeed(f"{cli} generatetodescriptor 101 \"$({cli} getdescriptorinfo 'raw(51)' | jq -r .descriptor)\"")

    machine.succeed("systemctl start public-pool.service")
    machine.wait_for_open_port(3333, timeout=120)
    machine.succeed("systemctl is-active public-pool.service")
    machine.wait_until_succeeds("journalctl -u public-pool | grep -q 'Stratum server is listening on port 3333'")
    out = machine.succeed(
      "exec 3<>/dev/tcp/127.0.0.1/3333; "
      "printf '%s\\n' '{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"test\"]}' >&3; "
      "timeout 10 head -n1 <&3"
    )
    assert '"id":1' in out and '"result"' in out, out
    machine.succeed("test -f /var/lib/public-pool/DB/public-pool.sqlite")
    machine.succeed("stat -c %U /proc/$(systemctl show -p MainPID --value public-pool) | grep -qx public-pool")
  '';
}
