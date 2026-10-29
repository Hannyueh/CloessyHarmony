import { asciiBytes, sameAscii } from './Bytes';

export enum ResponseKind {
  OPEN_ACK = 0,
  PASSWORD_ACK = 1,
  KEY_ERROR = 2,
  UNKNOWN_ACTION = 3,
  ENCRYPTED = 4
}

/** Immutable assembled envelope. Action tags are not a mechanical door result. */
export class ResponseFrame {
  readonly bytes: Uint8Array;
  readonly kind: ResponseKind;
  readonly action: number;

  constructor(bytes: Uint8Array, kind: ResponseKind, action: number) {
    this.bytes = bytes;
    this.kind = kind;
    this.action = action;
  }

  get length(): number {
    return this.bytes.length;
  }
}

export class FrameCodec {
  /** D0 | total length | ASCII secret | 0xA7. No password mutation. */
  static encodePlainOpen(secret: string): Uint8Array {
    if (secret.length === 0) {
      throw new Error('门锁凭据为空');
    }
    const key = asciiBytes(secret);
    if (key.length > 252) {
      throw new Error('门锁凭据超出普通帧长度上限');
    }
    const frame = new Uint8Array(key.length + 3);
    frame[0] = 0xD0;
    frame[1] = frame.length;
    frame.set(key, 2);
    frame[frame.length - 1] = 0xA7;
    return frame;
  }
}

/**
 * Bounded stream decoder for the observed D0 envelope. D2/D3 envelopes are kept
 * opaque (the caller decrypts them). A fresh assembler is used for each attempt.
 */
export class DoorResponseAssembler {
  private buffer: number[] = [];
  private readonly maxFrameLength: number;
  private discarded: number = 0;
  private malformed: number = 0;

  constructor(maxFrameLength: number = 255) {
    this.maxFrameLength = maxFrameLength;
  }

  get pendingCount(): number {
    return this.buffer.length;
  }

  get discardedBytes(): number {
    return this.discarded;
  }

  get malformedHeaders(): number {
    return this.malformed;
  }

  reset(): number {
    const count = this.buffer.length;
    this.buffer = [];
    return count;
  }

  feed(input: Uint8Array): ResponseFrame[] {
    const frames: ResponseFrame[] = [];
    for (let i = 0; i < input.length; i++) {
      const next = input[i];
      if (this.buffer.length === 0 && !this.isHeader(next)) {
        this.discarded++;
        continue;
      }
      this.buffer.push(next);
      let inspect = true;
      while (inspect && this.buffer.length > 0) {
        if (!this.isHeader(this.buffer[0])) {
          this.buffer.shift();
          this.discarded++;
          continue;
        }
        const encrypted = this.buffer[0] === 0xD2;
        const headerLength = encrypted ? 3 : 2;
        if (encrypted) {
          if (this.buffer.length < 2) {
            break;
          }
          if (this.buffer[1] !== 0xD3) {
            this.buffer.shift();
            this.discarded++;
            continue;
          }
        }
        if (this.buffer.length < headerLength) {
          break;
        }
        const length = this.buffer[headerLength - 1];
        if (length < 3 || length > this.maxFrameLength) {
          this.malformed++;
          this.buffer.shift();
          this.discarded++;
          continue;
        }
        if (this.buffer.length < length) {
          break;
        }
        const complete = new Uint8Array(length);
        for (let j = 0; j < length; j++) {
          complete[j] = this.buffer[j];
        }
        frames.push(encrypted ? new ResponseFrame(complete, ResponseKind.ENCRYPTED, -1)
          : DoorResponseAssembler.decodePlain(complete));
        this.buffer.splice(0, length);
        inspect = this.buffer.length > 0;
      }
    }
    return frames;
  }

  private static decodePlain(data: Uint8Array): ResponseFrame {
    const action = data[2];
    const payload = new Uint8Array(data.length - 3);
    payload.set(data.slice(3), 0);
    let kind = ResponseKind.UNKNOWN_ACTION;
    if (sameAscii(payload, 'SECRET_KEY_FAI') || sameAscii(payload, 'SECRET_KEY_FAIL')) {
      kind = ResponseKind.KEY_ERROR;
    } else if (action === 0xA7) {
      kind = ResponseKind.OPEN_ACK;
    } else if (action === 0xA5) {
      kind = ResponseKind.PASSWORD_ACK;
    }
    return new ResponseFrame(data, kind, action);
  }

  private isHeader(value: number): boolean {
    return value === 0xD0 || value === 0xD2;
  }
}
