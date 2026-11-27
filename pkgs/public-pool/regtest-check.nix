# Regtest end-to-end check: bitcoind + public-pool in the build sandbox; a test
# stratum client solves one block; assert the node took it as tip and the
# coinbase pays everything to the miner's address (DEV_FEE_ADDRESS blank).
{
  runCommand,
  bitcoind,
  nodejs_24,
  jq,
  public-pool,
}:
runCommand "public-pool-regtest" {nativeBuildInputs = [bitcoind nodejs_24 jq public-pool];} ''
  set -euo pipefail
  addr=bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080
  export HOME=$TMPDIR
  mkdir -p btc pool
  cat > btc/bitcoin.conf <<CONF
  regtest=1
  server=1
  listen=0
  [regtest]
  rpcbind=127.0.0.1
  rpcallowip=127.0.0.1
  rpcport=18443
  zmqpubrawblock=tcp://127.0.0.1:13000
  CONF
  cli() { bitcoin-cli -datadir=$PWD/btc "$@"; }
  bitcoind -datadir=$PWD/btc -daemonwait -pid=$PWD/btc/bitcoind.pid
  trap 'kill $(cat btc/bitcoind.pid) ''${poolpid:-} 2>/dev/null || true' EXIT
  desc=$(cli getdescriptorinfo 'raw(51)' | jq -r .descriptor)
  cli generatetodescriptor 101 "$desc" >/dev/null

  (cd pool && env BITCOIN_RPC_URL=http://127.0.0.1 BITCOIN_RPC_PORT=18443 \
    BITCOIN_RPC_TIMEOUT=10000 BITCOIN_RPC_COOKIEFILE=$PWD/../btc/regtest/.cookie \
    BITCOIN_ZMQ_HOST=tcp://127.0.0.1:13000 API_PORT=13334 STRATUM_PORT=13333 \
    DEV_FEE_ADDRESS= NETWORK=regtest API_SECURE=false POOL_IDENTIFIER=Regtest \
    EXTERNAL_SHARE_SUBMISSION_ENABLED=false public-pool > ../pool.log 2>&1) &
  poolpid=$!

  # Stratum opens ~10 s after start.
  for i in $(seq 60); do (exec 3<>/dev/tcp/127.0.0.1/13333) 2>/dev/null && break; sleep 1; done
  (exec 3<>/dev/tcp/127.0.0.1/13333) 2>/dev/null || { cat pool.log; echo "FAIL: stratum port never opened"; exit 1; }

  node ${./regtest-client.js} client.json || { cat client.json pool.log; echo "FAIL: client did not get a block accepted"; exit 1; }
  solved=$(jq -r .blockHash client.json)
  tip=$(cli getbestblockhash)
  [ "$tip" = "$solved" ] || { echo "FAIL: tip $tip != solved $solved"; exit 1; }
  height=$(cli getblockcount)
  [ "$height" = 102 ] || { echo "FAIL: height $height != 102"; exit 1; }

  cli getblock "$tip" 2 > block.json
  reward=$(cli getblockstats "$height" '["subsidy","totalfee"]' | jq '.subsidy + .totalfee')
  to_addr=$(jq --arg a "$addr" '[.tx[0].vout[] | select(.scriptPubKey.address == $a) | .value * 1e8 | round] | add' block.json)
  others=$(jq --arg a "$addr" '[.tx[0].vout[] | select(.scriptPubKey.address != $a) | .value * 1e8 | round] | add // 0' block.json)
  [ "$to_addr" = "$reward" ] && [ "$others" = 0 ] || { jq '.tx[0].vout' block.json; echo "FAIL: payout $to_addr sat to $addr, $others sat elsewhere, reward $reward sat"; exit 1; }

  echo "PASS: block $tip at height $height accepted as tip"
  echo "PASS: coinbase pays $to_addr of $reward sat (100%) to $addr; other outputs total $others sat"
  grep -m1 "BLOCK SUBMISSION RESPONSE" pool.log || true
  touch $out
''
