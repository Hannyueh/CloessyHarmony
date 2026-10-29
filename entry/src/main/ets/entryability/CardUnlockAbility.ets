import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rpc } from '@kit.IPCKit';
import { CardUnlockService } from '../services/CardUnlockService';

const DOMAIN = 0x1206;
const TAG = 'CardUnlockAbility';
const METHOD = 'unlockCard';

class CallResult implements rpc.Parcelable {
  private value: string;

  constructor(value: string) {
    this.value = value;
  }

  marshalling(sequence: rpc.MessageSequence): boolean {
    sequence.writeString(this.value);
    return true;
  }

  unmarshalling(sequence: rpc.MessageSequence): boolean {
    this.value = sequence.readString();
    return true;
  }
}

/**
 * No visible page: the card uses a call event so the app is not brought forward.
 * A call event requires params.method and a registered callee handler.
 */
export default class CardUnlockAbility extends UIAbility {
  private started: boolean = false;
  private cardToken: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'headless card unlock started');
    this.cardToken = CardUnlockAbility.readToken(want);
    this.registerCallee();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const token = CardUnlockAbility.readToken(want);
    if (token.length > 0) {
      this.cardToken = token;
    }
    this.registerCallee();
  }

  onDestroy(): void {
    try {
      this.callee.off(METHOD);
    } catch (error) {
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Intentionally no loadContent: this ability only runs the headless unlock.
  }

  private registerCallee(): void {
    try {
      this.callee.off(METHOD);
    } catch (error) {
    }
    try {
      this.callee.on(METHOD, (data: rpc.MessageSequence) => {
        const token = CardUnlockAbility.extractToken(data);
        if (token.length > 0) {
          this.cardToken = token;
        }
        hilog.info(DOMAIN, TAG, 'call received, token=%{public}s',
          this.cardToken.length > 0 ? 'present' : 'missing');
        this.start();
        return new CallResult('accepted');
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'callee registration failed');
    }
  }

  private static extractToken(data: rpc.MessageSequence): string {
    try {
      const raw = data.readString();
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const value = parsed['cardToken'];
      return typeof value === 'string' ? value : '';
    } catch (error) {
      return '';
    }
  }

  private static readToken(want: Want): string {
    const params = want.parameters;
    if (params === undefined) {
      return '';
    }
    const value = params['cardToken'];
    return typeof value === 'string' ? value : '';
  }

  private start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    CardUnlockService.run(this.context, this.cardToken).then(() => {
      this.context.terminateSelf().catch(() => {
      });
    }).catch(() => {
      this.context.terminateSelf().catch(() => {
      });
    });
  }
}
