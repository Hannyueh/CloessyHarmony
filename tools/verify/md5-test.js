const S = [7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
  5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
  4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
  6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21];
const K = [];
for (let i = 0; i < 64; i++) K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296);
function rotl(x, n) { return ((x << n) | (x >>> (32 - n))) >>> 0; }
function md5(bytes) {
  const withPadding = ((bytes.length + 9 + 63) & ~63);
  const buffer = new Uint8Array(withPadding);
  buffer.set(bytes);
  buffer[bytes.length] = 0x80;
  const view = new DataView(buffer.buffer);
  const bitLen = bytes.length * 8;
  view.setUint32(withPadding - 8, bitLen >>> 0, true);
  view.setUint32(withPadding - 4, Math.floor(bitLen / 4294967296), true);
  let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
  const M = new Array(16);
  for (let off = 0; off < withPadding; off += 64) {
    for (let i = 0; i < 16; i++) M[i] = view.getUint32(off + i * 4, true);
    let A = a0, B = b0, C = c0, D = d0;
    for (let i = 0; i < 64; i++) {
      let F, g;
      if (i < 16) { F = (B & C) | (~B & D); g = i; }
      else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }
      else if (i < 48) { F = B ^ C ^ D; g = (3 * i + 5) % 16; }
      else { F = C ^ (B | ~D); g = (7 * i) % 16; }
      const tmp = D;
      D = C; C = B;
      const sum = (A + F + K[i] + M[g]) >>> 0;
      B = (B + rotl(sum, S[i])) >>> 0;
      A = tmp;
    }
    a0 = (a0 + A) >>> 0; b0 = (b0 + B) >>> 0; c0 = (c0 + C) >>> 0; d0 = (d0 + D) >>> 0;
  }
  const out = new Uint8Array(16);
  const ov = new DataView(out.buffer);
  ov.setUint32(0, a0, true); ov.setUint32(4, b0, true); ov.setUint32(8, c0, true); ov.setUint32(12, d0, true);
  return Buffer.from(out).toString('hex');
}
const crypto = require('crypto');
const tests = ['', 'a', 'abc', 'yunmei', '云莓开门', '123456789012345678901234567890123456789012345678901234567890', '密码Password!@#'];
for (const t of tests) {
  const mine = md5(Buffer.from(t, 'utf8'));
  const want = crypto.createHash('md5').update(t, 'utf8').digest('hex');
  console.log(t.slice(0, 20), mine === want ? 'OK' : 'FAIL', mine, want);
}
