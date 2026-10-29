import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hexToBytes, sameAscii } from './Bytes';

/**
 * Official 4.2.2 application envelope (module f8d7): AES-128-CBC with PKCS7
 * padding and a fixed application key/IV. These are protocol constants, not a
 * user's lock secret. Nothing here is logged.
 */
export class KeyRejectedError extends Error {
  constructor() {
    super('门锁拒绝当前密钥');
    this.name = 'KeyRejectedError';
  }
}

export class EnvelopeError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EnvelopeError';
  }
}

export class AesEnvelope {
  private static readonly KEY_HEX: string = '94810265F7B0E3AC1A2DB50C0986374F';
  private static readonly IV_HEX: string = '4DB8100EC7635A9F7D20035AB864CFE1';

  static async wrapPlain(plain: Uint8Array): Promise<Uint8Array> {
    AesEnvelope.validatePlain(plain);
    const encrypted = await AesEnvelope.crypt(cryptoFramework.CryptoMode.ENCRYPT_MODE, plain);
    const length = encrypted.length + 3;
    if (length > 255) {
      throw new EnvelopeError('加密帧超出单字节长度字段');
    }
    const envelope = new Uint8Array(length);
    envelope[0] = 0xD2;
    envelope[1] = 0xD3;
    envelope[2] = length;
    envelope.set(encrypted, 3);
    return envelope;
  }

  static async unwrapToPlain(envelope: Uint8Array): Promise<Uint8Array> {
    if (envelope.length < 19 || envelope.length > 255
      || envelope[0] !== 0xD2 || envelope[1] !== 0xD3
      || envelope[2] !== envelope.length || (envelope.length - 3) % 16 !== 0) {
      throw new EnvelopeError('门锁返回的加密帧格式不正确');
    }
    const encrypted = envelope.slice(3);
    const plain = await AesEnvelope.crypt(cryptoFramework.CryptoMode.DECRYPT_MODE, encrypted);
    if (sameAscii(plain, 'SECRET_KEY_FAIL') || sameAscii(plain, 'SECRET_KEY_FAI')) {
      throw new KeyRejectedError();
    }
    try {
      AesEnvelope.validatePlain(plain);
    } catch (error) {
      throw new EnvelopeError('门锁返回的解密内容格式未确认');
    }
    return plain;
  }

  private static validatePlain(plain: Uint8Array): void {
    if (plain.length < 3 || plain.length > 255
      || plain[0] !== 0xD0 || plain[1] !== plain.length) {
      throw new EnvelopeError('需要完整的单个 D0 内层帧');
    }
  }

  private static async crypt(mode: cryptoFramework.CryptoMode, input: Uint8Array): Promise<Uint8Array> {
    const keyGen = cryptoFramework.createSymKeyGenerator('AES128');
    const key = await keyGen.convertKey({ data: hexToBytes(AesEnvelope.KEY_HEX) });
    const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
    const params: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: hexToBytes(AesEnvelope.IV_HEX) }
    };
    await cipher.init(mode, key, params);
    const result = await cipher.doFinal({ data: input });
    return result.data;
  }
}
