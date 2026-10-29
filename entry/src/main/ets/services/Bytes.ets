/** Byte helpers. All conversions are explicit and never mutate caller arrays. */

export function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim();
  if (clean.length === 0 || clean.length % 2 !== 0) {
    throw new Error('固定参数格式不正确');
  }
  const result = new Uint8Array(clean.length / 2);
  for (let i = 0; i < result.length; i++) {
    const high = parseInt(clean.substring(i * 2, i * 2 + 1), 16);
    const low = parseInt(clean.substring(i * 2 + 1, i * 2 + 2), 16);
    if (Number.isNaN(high) || Number.isNaN(low)) {
      throw new Error('固定参数格式不正确');
    }
    result[i] = (high << 4) | low;
  }
  return result;
}

export function bytesToHex(bytes: Uint8Array): string {
  let text = '';
  for (let i = 0; i < bytes.length; i++) {
    const value = bytes[i];
    text += (value < 16 ? '0' : '') + value.toString(16);
  }
  return text;
}

export function asciiBytes(text: string): Uint8Array {
  const result = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code > 0x7F) {
      throw new Error('门锁凭据必须是 ASCII 文本');
    }
    result[i] = code;
  }
  return result;
}

export function bytesToAscii(bytes: Uint8Array): string {
  let text = '';
  for (let i = 0; i < bytes.length; i++) {
    text += String.fromCharCode(bytes[i]);
  }
  return text;
}

export function concatBytes(first: Uint8Array, second: Uint8Array): Uint8Array {
  const result = new Uint8Array(first.length + second.length);
  result.set(first, 0);
  result.set(second, first.length);
  return result;
}

export function sameBytes(first: Uint8Array, second: Uint8Array): boolean {
  if (first.length !== second.length) {
    return false;
  }
  for (let i = 0; i < first.length; i++) {
    if (first[i] !== second[i]) {
      return false;
    }
  }
  return true;
}

export function sameAscii(bytes: Uint8Array, text: string): boolean {
  if (bytes.length !== text.length) {
    return false;
  }
  for (let i = 0; i < bytes.length; i++) {
    if (bytes[i] !== text.charCodeAt(i)) {
      return false;
    }
  }
  return true;
}

export function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  const view = new Uint8Array(buffer);
  view.set(bytes);
  return buffer;
}

export function fromArrayBuffer(buffer: ArrayBuffer): Uint8Array {
  return new Uint8Array(buffer.slice(0));
}
