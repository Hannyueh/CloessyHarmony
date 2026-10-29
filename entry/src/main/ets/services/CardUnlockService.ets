import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from './AppModel';
import { LiveViewService } from './LiveViewService';
import { StageUpdate, UnlockStage } from '../model/Models';
import { delay } from './AsyncUtil';

const DOMAIN = 0x1205;
const TAG = 'CardUnlock';

/**
 * Headless unlock started by the desktop card's call event. It never loads a
 * page; progress is pushed to the card through formProvider. Requires the user
 * to have logged in and granted Bluetooth permission at least once.
 */
export class CardUnlockService {
  static running: boolean = false;
  private static lastText: string = '';
  private static lastStep: number = -99;

  static async run(context: common.UIAbilityContext, token: string): Promise<void> {
    if (CardUnlockService.running) {
      return;
    }
    const model = AppModel.shared;
    if (AppStorage.get<boolean>('appUnlocking') === true) {
      const since = AppStorage.get<number>('cardUnlockingAt') ?? 0;
      if (since > 0 && Date.now() - since < 120000) {
        try {
          await model.init(context);
          if (!model.verifyCardToken(token)) {
            await model.setCardProgress('请打开应用完成卡片初始化', 0, false);
            return;
          }
          await model.setCardProgress('应用正在开门', 2, true);
        } catch (error) {
        }
        return;
      }
      // A killed background ability can leave the flag behind; expire it.
      AppStorage.set<boolean>('appUnlocking', false);
    }
    CardUnlockService.running = true;
    AppStorage.setOrCreate<number>('cardUnlockingAt', Date.now());
    AppStorage.setOrCreate<boolean>('appUnlocking', true);
    CardUnlockService.lastText = '';
    CardUnlockService.lastStep = -99;
    let requestId = -1;
    try {
      const info = backgroundTaskManager.requestSuspendDelay('正在开门', () => {
      });
      requestId = info.requestId;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'suspend delay unavailable');
    }
    try {
      await model.init(context);
      if (!model.verifyCardToken(token)) {
        await model.setCardProgress('请打开应用完成卡片初始化', 0, false);
        return;
      }
      if (model.savedUsername.length === 0) {
        await model.setCardProgress('请先在应用内登录', 0, false);
        return;
      }
      const manager = abilityAccessCtrl.createAtManager();
      const status = manager.checkAccessTokenSync(context.applicationInfo.accessTokenId,
        'ohos.permission.ACCESS_BLUETOOTH');
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
        await model.setCardProgress('请先在应用内授权蓝牙', 0, false);
        return;
      }
      await model.setCardProgress('正在准备开门', 0, true);
      const restored = await model.restore();
      if (!restored) {
        await model.setCardProgress('登录已失效，请打开应用', 0, false);
        return;
      }
      await model.setCardProgress('正在刷新门锁凭据', 1, true);
      await LiveViewService.start('Cloessy 开门', '正在刷新凭据');
      try {
        await model.refreshForUnlock(true);
      } catch (error) {
        await LiveViewService.finish(false, '开门失败');
        await model.setCardProgress('开门失败：' + (error as Error).message, -1, false);
        return;
      }
      const outcome = await model.unlockWithRetry((update: StageUpdate) => {
        CardUnlockService.onStage(model, update);
      });
      await model.recordOutcome(outcome);
      if (outcome.isSuccess) {
        await model.toggleHomeColor();
      }
      await LiveViewService.finish(outcome.isSuccess, outcome.isSuccess ? '已开门' : '开门失败');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'headless unlock failed');
      await LiveViewService.finish(false, '开门失败');
      try {
        await model.setCardProgress('开门失败：' + (error as Error).message, -1, false);
      } catch (ignored) {
      }
    } finally {
      if (requestId >= 0) {
        try {
          backgroundTaskManager.cancelSuspendDelay(requestId);
        } catch (error) {
        }
      }
      CardUnlockService.running = false;
      AppStorage.setOrCreate<number>('cardUnlockingAt', 0);
      AppStorage.setOrCreate<boolean>('appUnlocking', false);
    }
  }

  private static onStage(model: AppModel, update: StageUpdate): void {
    let step = 0;
    let text = '';
    if (update.stage === UnlockStage.PREPARING) {
      step = 1;
      text = update.text;
    } else if (update.stage === UnlockStage.CONNECTING) {
      step = 2;
      text = '正在连接门锁';
    } else if (update.stage === UnlockStage.DISCOVERING) {
      step = 2;
      text = '正在发现门锁服务';
    } else if (update.stage === UnlockStage.SUBSCRIBING) {
      step = 3;
      text = '正在订阅门锁通知';
    } else if (update.stage === UnlockStage.SENDING) {
      step = 4;
      text = '正在发送开锁指令';
    } else if (update.stage === UnlockStage.WAITING) {
      step = 4;
      text = '等待门锁返回';
    }
    if (text.length === 0 || (step === CardUnlockService.lastStep && text === CardUnlockService.lastText)) {
      return;
    }
    CardUnlockService.lastStep = step;
    CardUnlockService.lastText = text;
    LiveViewService.update(step * 20, text).catch(() => {
    });
    model.setCardProgress(text, step, true).catch(() => {
    });
  }
}
