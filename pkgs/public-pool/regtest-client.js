const net = require('net'), crypto = require('crypto'), fs = require('fs');
const ADDRESS = 'bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080';
const sha = b => crypto.createHash('sha256').update(b).digest();
const dsha = b => sha(sha(b));
const rev = b => Buffer.from(b).reverse();
const swapWords = h => Buffer.concat(h.match(/.{8}/g).map(w => rev(Buffer.from(w, 'hex'))));
const target = bits => {
  const n = parseInt(bits, 16), e = n >>> 24, m = BigInt(n & 0x7fffff);
  return e <= 3 ? m >> BigInt(8 * (3 - e)) : m << BigInt(8 * (e - 3));
};
const out = { events: [] };
let en1, en2Size, solved = false, buf = '';
const s = net.connect(13333, '127.0.0.1');
const send = o => s.write(JSON.stringify(o) + '\n');
const finish = c => { fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 2)); s.destroy(); process.exit(c); };
setTimeout(() => { out.error = 'timeout'; finish(1); }, 60000);
s.on('connect', () => send({ id: 1, method: 'mining.subscribe', params: ['practice-client/1.0'] }));
s.on('error', e => { out.error = String(e); finish(1); });
s.on('data', d => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const l = buf.slice(0, i);
    buf = buf.slice(i + 1);
    if (l.trim()) handle(JSON.parse(l));
  }
});
function handle(m) {
  if (m.id === 1) {
    en1 = m.result[1]; en2Size = m.result[2]; out.subscribe = m.result;
    send({ id: 2, method: 'mining.suggest_difficulty', params: [1e-10] });
    send({ id: 3, method: 'mining.authorize', params: [ADDRESS + '.practice', 'x'] });
    return;
  }
  if (m.id === 3) { out.authorize = m.result; return; }
  if (m.id === 4) { out.submitResponse = m; finish(m.result === true ? 0 : 1); return; }
  if (m.method === 'mining.set_difficulty') { out.difficulty = m.params[0]; out.events.push('set_difficulty ' + m.params[0]); return; }
  if (m.method === 'mining.notify' && !solved) { out.events.push('notify job ' + m.params[0]); solved = true; mine(m.params); }
}
function mine([job, prev, c1, c2, branch, ver, bits, ntime]) {
  const en2 = '00'.repeat(en2Size), t = target(bits);
  let root = dsha(Buffer.from(c1 + en1 + en2 + c2, 'hex'));
  for (const b of branch) root = dsha(Buffer.concat([root, Buffer.from(b, 'hex')]));
  const h = Buffer.alloc(80);
  h.writeUInt32LE(parseInt(ver, 16), 0);
  swapWords(prev).copy(h, 4);
  root.copy(h, 36);
  h.writeUInt32LE(parseInt(ntime, 16), 68);
  h.writeUInt32LE(parseInt(bits, 16), 72);
  for (let n = 0; n <= 0xffffffff; n++) {
    h.writeUInt32LE(n, 76);
    const r = rev(dsha(h));
    if (BigInt('0x' + r.toString('hex')) <= t) {
      Object.assign(out, { job, nbits: bits, nonce: n, attempts: n + 1, blockHash: r.toString('hex') });
      send({ id: 4, method: 'mining.submit', params: [ADDRESS + '.practice', job, en2, ntime, n.toString(16).padStart(8, '0')] });
      return;
    }
  }
}
