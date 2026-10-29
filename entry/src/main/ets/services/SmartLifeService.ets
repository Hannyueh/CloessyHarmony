import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from './AppModel';
import { LiveViewService } from './LiveViewService';
import { StageUpdate, UnlockStage } from '../model/Models';
import { delay } from './AsyncUtil';

const DOMAIN = 0x1211;
const TAG = 'CloessyScene';

/**
 * Headless unlock used by the Smart Life shortcut/app-service entry. It never
 * loads a page; the existing card and live view show progress.
 */
export class SmartLifeService {
  private static running: boolean = false;

  static async run(context: common.UIAbilityContext): Promise<void> {
    if (SmartLifeService.running) {
      return;
    }
    if (AppStorage.get<boolean>('appUnlocking') === true) {
      return;
    }
    SmartLifeService.running = true;
    AppStorage.setOrCreate<boolean>('appUnlocking', true);
    AppStorage.setOrCreate<number>('cardUnlockingAt', Date.now());
    const model = AppModel.shared;
    let requestId = -1;
    try {
      const info = backgroundTaskManager.requestSuspendDelay('Cloessy 正在开门', () => {
      });
      requestId = info.requestId;
    } catch (error) {
    }
    try {
      await model.init(context);
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
      await model.refreshForUnlock(true);
      await LiveViewService.start('Cloessy 开门', '智慧生活场景开门');
      const outcome = await model.unlockWithRetry((update: StageUpdate) => {
        let progress = 0.4;
        if (update.stage === UnlockStage.PREPARING || update.stage === UnlockStage.REFRESHING) {
          progress = 0.2;
        } else if (update.stage === UnlockStage.CONNECTING) {
          progress = 0.4;
        } else if (update.stage === UnlockStage.DISCOVERING || update.stage === UnlockStage.SUBSCRIBING) {
          progress = 0.6;
        } else if (update.stage === UnlockStage.SENDING) {
          progress = 0.8;
        } else if (update.stage === UnlockStage.WAITING) {
          progress = 0.8;
        }
        LiveViewService.update(progress * 100, update.text).catch(() => {
        });
        model.setCardProgress(update.text, Math.max(1, Math.round(progress * 5)), true).catch(() => {
        });
      });
      await model.recordOutcome(outcome);
      if (outcome.isSuccess) {
        await model.toggleHomeColor();
      }
      await LiveViewService.finish(outcome.isSuccess, outcome.isSuccess ? '已开门' : '开门失败');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'smart life unlock failed');
      try {
        await AppModel.shared.setCardProgress('开门失败', -1, false);
      } catch (ignored) {
      }
      await LiveViewService.finish(false, '开门失败').catch(() => {
      });
    } finally {
      if (requestId >= 0) {
        try {
          backgroundTaskManager.cancelSuspendDelay(requestId);
        } catch (error) {
        }
      }
      SmartLifeService.running = false;
      AppStorage.setOrCreate<boolean>('appUnlocking', false);
    }
  }
}
