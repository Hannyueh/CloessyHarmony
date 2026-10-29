import { access, ble, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DoorLockInfo, StageUpdate, UnlockKind, UnlockOutcome, UnlockStage } from '../model/Models';
import { AesEnvelope, KeyRejectedError } from './AesEnvelope';
import { fromArrayBuffer, toArrayBuffer } from './Bytes';
import { DoorResponseAssembler, FrameCodec, ResponseFrame, ResponseKind } from './FrameProtocol';
import { delay, withTimeout } from './AsyncUtil';

export type ProgressCallback = (update: StageUpdate) => void;

const DOMAIN: number = 0x1204;
const TAG: string = 'BleUnlock';
const MAC_PATTERN = new RegExp('^([0-9A-F]{2}:){5}[0-9A-F]{2}$');
const PACKET_BYTES: number = 20;
const PACKET_INTERVAL_MS: number = 120;
const CONNECT_TIMEOUT_MS: number = 20000;
const OPERATION_TIMEOUT_MS: number = 10000;
const RESPONSE_TIMEOUT_MS: number = 10000;

class Runtime {
  settled: boolean = false;
  connected: boolean = false;
  wrote: boolean = false;
  aes: boolean = false;
  connectedResolve: (() => void) | null = null;
  connectedReject: ((error: Error) => void) | null = null;
  outcomeResolve: ((outcome: UnlockOutcome) => void) | null = null;
  queue: Uint8Array[] = [];
  processing: boolean = false;
  assembler: DoorResponseAssembler = new DoorResponseAssembler();
}

function settle(runtime: Runtime, outcome: UnlockOutcome): void {
  if (runtime.settled) {
    return;
  }
  runtime.settled = true;
  hilog.info(DOMAIN, TAG, 'result kind=%{public}d, wrote=%{public}s',
    outcome.kind, runtime.wrote ? 'yes' : 'no');
  const resolve = runtime.outcomeResolve;
  runtime.outcomeResolve = null;
  if (resolve !== null) {
    resolve(outcome);
  }
}

function mapBluetoothError(error: Error): string {
  const business = error as BusinessError;
  if (business.code === 201) {
    return '缺少蓝牙权限，请在系统设置中允许云莓开门使用蓝牙后重试';
  }
  if (business.code === 801) {
    return '当前设备不支持低功耗蓝牙';
  }
  if (business.code === 2900003) {
    return '蓝牙已关闭，请先开启蓝牙';
  }
  if (business.code === 2900005) {
    return '未找到目标门锁，请靠近寝室门锁后重试';
  }
  return error.message.length > 0 ? error.message : '蓝牙操作失败，请稍后重试';
}

/**
 * One OPEN attempt per connection. The frame layout follows the official 4.2.2
 * OPEN path; a real lock still has to confirm the mechanical result.
 */
export class BleUnlockService {
  private static cancelled: boolean = false;
  private static activeClient: ble.GattClientDevice | null = null;

  static cancel(): void {
    BleUnlockService.cancelled = true;
    const client = BleUnlockService.activeClient;
    BleUnlockService.activeClient = null;
    if (client !== null) {
      try { client.disconnect(); } catch (error) { }
      try { client.close(); } catch (error) { }
    }
  }

  static async unlock(lock: DoorLockInfo, onProgress: ProgressCallback,
    preferScan: boolean = false): Promise<UnlockOutcome> {
    if (lock.secret.length === 0 || lock.blockedReason.length > 0 || !lock.aesKnown) {
      const reason = lock.blockedReason.length > 0 ? lock.blockedReason : '门锁信息不完整';
      return new UnlockOutcome(UnlockKind.UNSUPPORTED, reason + '；未发送开锁指令', false);
    }
    let wire: Uint8Array;
    try {
      const plain = FrameCodec.encodePlainOpen(lock.secret);
      wire = lock.aesSupport ? await AesEnvelope.wrapPlain(plain) : plain;
    } catch (error) {
      return new UnlockOutcome(UnlockKind.UNSUPPORTED, '无法按门锁能力生成开锁指令', false);
    }
    try {
      if (access.getState() !== access.BluetoothState.STATE_ON) {
        return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, '请先开启蓝牙', false);
      }
    } catch (error) {
      return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, mapBluetoothError(error as Error), false);
    }

    let deviceId = lock.mac.toUpperCase();
    if (preferScan || !MAC_PATTERN.test(deviceId)) {
      onProgress(new StageUpdate(UnlockStage.CONNECTING, '正在扫描门锁',
        preferScan ? '重新搜索附近门锁' : '未保存门锁地址，按服务特征搜索'));
      try {
        deviceId = await BleUnlockService.scan(lock.serviceUuid);
      } catch (error) {
        return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, mapBluetoothError(error as Error), false);
      }
    }
    hilog.info(DOMAIN, TAG, 'connect attempt, aes=%{public}s, scan=%{public}s',
      lock.aesSupport ? 'AES' : 'PLAIN', preferScan ? 'yes' : 'no');

    const runtime = new Runtime();
    runtime.aes = lock.aesSupport;
    let client: ble.GattClientDevice;
    try {
      client = ble.createGattClientDevice(deviceId);
      BleUnlockService.activeClient = client;
    } catch (error) {
      return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, mapBluetoothError(error as Error), false);
    }

    const connectedPromise = new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
      runtime.connectedResolve = resolve;
      runtime.connectedReject = reject;
    });
    const outcomePromise = new Promise<UnlockOutcome>((resolve: (outcome: UnlockOutcome) => void) => {
      runtime.outcomeResolve = resolve;
    });

    const onStateChange = (change: ble.BLEConnectionChangeState): void => {
      if (change.state === constant.ProfileConnectionState.STATE_CONNECTED) {
        runtime.connected = true;
        const resolve = runtime.connectedResolve;
        runtime.connectedResolve = null;
        if (resolve !== null) {
          resolve();
        }
        return;
      }
      if (change.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
        const reject = runtime.connectedReject;
        runtime.connectedReject = null;
        if (!runtime.connected && reject !== null) {
          reject(new Error('连接门锁失败'));
          return;
        }
        if (runtime.connected) {
          settle(runtime, new UnlockOutcome(UnlockKind.UNCONFIRMED,
            '连接已断开，开锁结果未确认', runtime.wrote));
        }
      }
    };

    const onChanged = (characteristic: ble.BLECharacteristic): void => {
      if (runtime.settled || !runtime.wrote) {
        return;
      }
      if (characteristic.characteristicUuid.toLowerCase() !== lock.notifyUuid) {
        return;
      }
      const data = fromArrayBuffer(characteristic.characteristicValue);
      if (data.length === 0) {
        return;
      }
      runtime.queue.push(data);
      BleUnlockService.drain(runtime).catch(() => {
        settle(runtime, new UnlockOutcome(UnlockKind.UNCONFIRMED, '门锁返回处理失败，结果未确认', runtime.wrote));
      });
    };

    try {
      client.on('BLEConnectionStateChange', onStateChange);
      client.on('BLECharacteristicChange', onChanged);

      onProgress(new StageUpdate(UnlockStage.CONNECTING, '正在连接门锁', deviceId));
      client.connect();
      await withTimeout(connectedPromise, CONNECT_TIMEOUT_MS, '连接门锁超时，请靠近门锁后重试');
      await delay(200);

      onProgress(new StageUpdate(UnlockStage.DISCOVERING, '正在发现门锁服务', ''));
      let services: ble.GattService[] = [];
      for (let attempt = 0; attempt < 5; attempt++) {
        try {
          services = await withTimeout(client.getServices(), 4000, '服务发现超时');
        } catch (error) {
          if (attempt === 4) {
            throw error as Error;
          }
        }
        if (services.length > 0) {
          break;
        }
        await delay(350);
      }
      if (services.length === 0) {
        return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, '门锁没有返回可用的蓝牙服务', false);
      }

      let service: ble.GattService | null = null;
      for (let i = 0; i < services.length; i++) {
        if (services[i].serviceUuid.toLowerCase() === lock.serviceUuid) {
          service = services[i];
          break;
        }
      }
      if (service === null) {
        return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, '目标服务不存在，门锁信息可能不匹配', false);
      }

      let writeChar: ble.BLECharacteristic | null = null;
      let notifyChar: ble.BLECharacteristic | null = null;
      const characteristics = service.characteristics;
      for (let i = 0; i < characteristics.length; i++) {
        const current = characteristics[i];
        const uuid = current.characteristicUuid.toLowerCase();
        if (uuid === lock.writeUuid) {
          writeChar = current;
        } else if (uuid === lock.notifyUuid) {
          notifyChar = current;
        }
      }
      if (writeChar === null || notifyChar === null) {
        return new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, '门锁写入或通知特征不存在', false);
      }

      let writeType: ble.GattWriteType = ble.GattWriteType.WRITE;
      const writeProps = writeChar.properties;
      if (writeProps !== undefined) {
        if (writeProps.write === true) {
          writeType = ble.GattWriteType.WRITE;
        } else if (writeProps.writeNoResponse === true) {
          writeType = ble.GattWriteType.WRITE_NO_RESPONSE;
        } else {
          return new UnlockOutcome(UnlockKind.UNSUPPORTED, '目标特征不支持写入', false);
        }
      }

      onProgress(new StageUpdate(UnlockStage.SUBSCRIBING, '正在订阅门锁返回通知', ''));
      const notifyProps = notifyChar.properties;
      const useNotify = notifyProps === undefined || notifyProps.notify === true;
      if (useNotify) {
        await withTimeout(client.setCharacteristicChangeNotification(notifyChar, true),
          OPERATION_TIMEOUT_MS, '订阅门锁通知超时');
      } else if (notifyProps !== undefined && notifyProps.indicate === true) {
        await withTimeout(client.setCharacteristicChangeIndication(notifyChar, true),
          OPERATION_TIMEOUT_MS, '订阅门锁通知超时');
      } else {
        return new UnlockOutcome(UnlockKind.UNSUPPORTED, '目标特征不支持通知或指示', false);
      }
      await delay(120);

      onProgress(new StageUpdate(UnlockStage.SENDING, '正在发送开锁指令', wire.length + ' 字节'));
      runtime.wrote = false;
      let offset = 0;
      while (offset < wire.length) {
        if (runtime.settled) {
          break;
        }
        const end = Math.min(offset + PACKET_BYTES, wire.length);
        const chunk = wire.slice(offset, end);
        writeChar.characteristicValue = toArrayBuffer(chunk);
        runtime.wrote = true;
        await withTimeout(client.writeCharacteristicValue(writeChar, writeType),
          OPERATION_TIMEOUT_MS, '发送开锁指令超时');
        offset = end;
        if (offset < wire.length) {
          await delay(PACKET_INTERVAL_MS);
        }
      }

      onProgress(new StageUpdate(UnlockStage.WAITING, '请求已发送，正在等待门锁返回', '尚未确认开门'));
      let outcome: UnlockOutcome;
      try {
        outcome = await withTimeout(outcomePromise, RESPONSE_TIMEOUT_MS, '等待门锁返回超时');
      } catch (error) {
        outcome = new UnlockOutcome(UnlockKind.UNCONFIRMED,
          '未收到可验证的开锁返回，请确认门锁实际状态', runtime.wrote);
      }
      onProgress(new StageUpdate(UnlockStage.FINISHED, '本次开门流程结束', ''));
      return outcome;
    } catch (error) {
      const message = mapBluetoothError(error as Error);
      return new UnlockOutcome(runtime.wrote ? UnlockKind.UNCONFIRMED : UnlockKind.TRANSPORT_ERROR,
        message, runtime.wrote);
    } finally {
      runtime.settled = true;
      try {
        client.off('BLEConnectionStateChange', onStateChange);
      } catch (error) {
      }
      try {
        client.off('BLECharacteristicChange', onChanged);
      } catch (error) {
      }
      try {
        client.disconnect();
      } catch (error) {
      }
      try {
        client.close();
      if (BleUnlockService.activeClient === client) {
        BleUnlockService.activeClient = null;
      }
      } catch (error) {
      }
    }
  }

  private static async drain(runtime: Runtime): Promise<void> {
    if (runtime.processing || runtime.settled) {
      return;
    }
    runtime.processing = true;
    try {
      while (!runtime.settled && runtime.queue.length > 0) {
        const data = runtime.queue.shift();
        if (data === undefined) {
          continue;
        }
        await BleUnlockService.decode(runtime, data);
      }
    } finally {
      runtime.processing = false;
    }
  }

  private static async decode(runtime: Runtime, data: Uint8Array): Promise<void> {
    let frames: ResponseFrame[] = [];
    try {
      frames = runtime.assembler.feed(data);
    } catch (error) {
      settle(runtime, new UnlockOutcome(UnlockKind.UNCONFIRMED,
        '门锁返回数据超出已验证格式，开锁结果未确认', runtime.wrote));
      return;
    }
    for (let i = 0; i < frames.length; i++) {
      const frame = frames[i];
      if (frame.kind === ResponseKind.ENCRYPTED) {
        if (!runtime.aes) {
          settle(runtime, new UnlockOutcome(UnlockKind.UNSUPPORTED,
            '返回的加密格式与门锁能力信息不一致', runtime.wrote));
          return;
        }
        let plain: Uint8Array;
        try {
          plain = await AesEnvelope.unwrapToPlain(frame.bytes);
        } catch (error) {
          if (error instanceof KeyRejectedError) {
            settle(runtime, new UnlockOutcome(UnlockKind.KEY_REJECTED,
              '门锁返回密钥错误，请刷新门锁凭据后重试', runtime.wrote));
          } else {
            settle(runtime, new UnlockOutcome(UnlockKind.UNCONFIRMED,
              '无法验证门锁的加密返回，开锁结果未确认', runtime.wrote));
          }
          return;
        }
        const inner = new DoorResponseAssembler();
        const innerFrames = inner.feed(plain);
        if (innerFrames.length !== 1 || inner.pendingCount !== 0) {
          settle(runtime, new UnlockOutcome(UnlockKind.UNCONFIRMED,
            '门锁返回的内层帧尚未确认', runtime.wrote));
          return;
        }
        BleUnlockService.applyFrame(runtime, innerFrames[0]);
      } else {
        BleUnlockService.applyFrame(runtime, frame);
      }
      if (runtime.settled) {
        return;
      }
    }
  }

  private static applyFrame(runtime: Runtime, frame: ResponseFrame): void {
    if (frame.kind === ResponseKind.KEY_ERROR) {
      settle(runtime, new UnlockOutcome(UnlockKind.KEY_REJECTED,
        '门锁返回密钥错误，请刷新门锁凭据后重试', runtime.wrote));
      return;
    }
    if (frame.kind === ResponseKind.OPEN_ACK) {
      settle(runtime, new UnlockOutcome(UnlockKind.ACKNOWLEDGED,
        '门锁已返回开锁动作确认，请留意门锁实际状态', runtime.wrote));
    }
  }

  private static async scan(serviceUuid: string): Promise<string> {
    const filter: ble.ScanFilter = { serviceUuid: serviceUuid };
    const options: ble.ScanOptions = {
      dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY,
      matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
    };
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Error) => void) => {
      let finished = false;
      const finish = (deviceId: string, error: Error | null): void => {
        if (finished) {
          return;
        }
        finished = true;
        try {
          ble.stopBLEScan();
        } catch (stopError) {
        }
        try {
          ble.off('BLEDeviceFind');
        } catch (offError) {
        }
        if (error !== null) {
          reject(error);
        } else {
          resolve(deviceId);
        }
      };
      ble.on('BLEDeviceFind', (results: ble.ScanResult[]) => {
        for (let i = 0; i < results.length; i++) {
          const found = results[i];
          if (found.deviceId.length > 0 && found.connectable !== false) {
            finish(found.deviceId, null);
            return;
          }
        }
      });
      try {
        ble.startBLEScan([filter], options);
      } catch (error) {
        finish('', error as Error);
        return;
      }
      setTimeout(() => {
        finish('', new Error('扫描超时，未找到目标门锁'));
      }, 12000);
    });
  }
}
