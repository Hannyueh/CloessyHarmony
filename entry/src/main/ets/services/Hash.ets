import { util } from '@kit.ArkTS';

/**
 * Pure ArkTS MD5. The service expects UTF-8 text hashed with MD5, and the digest
 * is a reusable credential, so it is never logged.
 */
const SHIFT: number[] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
];

let cachedK: number[] | null = null;

function kValues(): number[] {
  if (cachedK !== null) {
    return cachedK;
  }
  const table: number[] = [];
  for (let i = 0; i < 64; i++) {
    table.push(Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296));
  }
  cachedK = table;
  return table;
}

function rotateLeft(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function readWord(bytes: Uint8Array, offset: number): number {
  return (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)) >>> 0;
}

function wordHex(value: number): string {
  let text = '';
  for (let i = 0; i < 4; i++) {
    const byte = (value >>> (i * 8)) & 0xFF;
    text += (byte < 16 ? '0' : '') + byte.toString(16);
  }
  return text;
}

export function md5Hex(text: string): string {
  const encoder = new util.TextEncoder();
  const source = encoder.encodeInto(text);
  const paddedLength = (source.length + 9 + 63) & ~63;
  const buffer = new Uint8Array(paddedLength);
  buffer.set(source, 0);
  buffer[source.length] = 0x80;

  const bitLength = source.length * 8;
  const low = bitLength >>> 0;
  const high = Math.floor(bitLength / 4294967296);
  const tail = paddedLength - 8;
  buffer[tail] = low & 0xFF;
  buffer[tail + 1] = (low >>> 8) & 0xFF;
  buffer[tail + 2] = (low >>> 16) & 0xFF;
  buffer[tail + 3] = (low >>> 24) & 0xFF;
  buffer[tail + 4] = high & 0xFF;
  buffer[tail + 5] = (high >>> 8) & 0xFF;
  buffer[tail + 6] = (high >>> 16) & 0xFF;
  buffer[tail + 7] = (high >>> 24) & 0xFF;

  const table = kValues();
  let a0 = 0x67452301;
  let b0 = 0xEFCDAB89;
  let c0 = 0x98BADCFE;
  let d0 = 0x10325476;
  const block = new Array<number>(16);

  for (let offset = 0; offset < paddedLength; offset += 64) {
    for (let i = 0; i < 16; i++) {
      block[i] = readWord(buffer, offset + i * 4);
    }
    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;
    for (let i = 0; i < 64; i++) {
      let f = 0;
      let g = 0;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * i) % 16;
      }
      const previousD = d;
      d = c;
      c = b;
      const sum = (a + f + table[i] + block[g]) >>> 0;
      b = (b + rotateLeft(sum, SHIFT[i])) >>> 0;
      a = previousD;
    }
    a0 = (a0 + a) >>> 0;
    b0 = (b0 + b) >>> 0;
    c0 = (c0 + c) >>> 0;
    d0 = (d0 + d) >>> 0;
  }
  return wordHex(a0) + wordHex(b0) + wordHex(c0) + wordHex(d0);
}
