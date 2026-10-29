import { liveViewManager } from '@kit.LiveViewKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x1210;
const TAG = 'CloessyLiveView';
const EVENT = 'UNLOCK';

/**
 * Best-effort system Live View for the unlock progress.
 *
 * Live View requires the AGC Live View Kit entitlement and a profile that
 * contains it. Without that entitlement startLiveView fails; the app then keeps
 * working normally and the in-app/card progress remains the source of truth.
 */
export class LiveViewService {
  private static running: boolean = false;
  private static sequence: number = 0;
  private static lastProgress: number = -1;
  private static lastText: string = '';

  static async start(title: string, text: string): Promise<void> {
    if (LiveViewService.running) {
      await LiveViewService.update(0, text);
      return;
    }
    try {
      if (!canIUse('SystemCapability.LiveView.LiveViewService')) {
        return;
      }
      const enabled = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        hilog.info(DOMAIN, TAG, 'live view is disabled on this device');
        return;
      }
      LiveViewService.sequence = 0;
      LiveViewService.lastProgress = -1;
      LiveViewService.lastText = '';
      const view = LiveViewService.build(title, text, 0);
      const result = await liveViewManager.startLiveView(view);
      if (result.resultCode === 0) {
        LiveViewService.running = true;
        LiveViewService.sequence = 1;
        LiveViewService.lastProgress = 0;
        LiveViewService.lastText = text;
      } else {
        hilog.warn(DOMAIN, TAG, 'start rejected: %{public}d', result.resultCode);
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'start failed: %{public}d', err.code);
    }
  }

  static async update(progress: number, text: string): Promise<void> {
    if (!LiveViewService.running) {
      return;
    }
    const clamped = Math.max(0, Math.min(100, Math.round(progress)));
    if (clamped === LiveViewService.lastProgress && text === LiveViewService.lastText) {
      return;
    }
    try {
      const view = LiveViewService.build('Cloessy 开门', text, clamped);
      const result = await liveViewManager.updateLiveView(view);
      if (result.resultCode === 0) {
        LiveViewService.sequence += 1;
        LiveViewService.lastProgress = clamped;
        LiveViewService.lastText = text;
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'update failed: %{public}d', err.code);
    }
  }

  static async finish(success: boolean, text: string): Promise<void> {
    if (!LiveViewService.running) {
      return;
    }
    try {
      const view = LiveViewService.build('Cloessy 开门', text, 100);
      if (success) {
        view.liveViewData.primary.keepTime = 4;
        await liveViewManager.stopLiveView(view);
      } else {
        await liveViewManager.stopLiveView(view);
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'finish failed: %{public}d', err.code);
    } finally {
      LiveViewService.running = false;
      LiveViewService.lastProgress = -1;
    }
  }

  private static build(title: string, text: string, progress: number): liveViewManager.LiveView {
    const content: liveViewManager.RichText[] = [
      { text: text, textColor: '#FFE9E4DA' }
    ];
    const layout: liveViewManager.ProgressLayout = {
      layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
      progress: progress,
      color: '#FFE9E4DA',
      backgroundColor: '#33171D29',
      lineType: liveViewManager.LineType.LINE_TYPE_NORMAL_SOLID_LINE,
      indicatorType: liveViewManager.IndicatorType.INDICATOR_TYPE_UNDISPLAYED
    };
    const capsule: liveViewManager.ProgressCapsule = {
      type: liveViewManager.CapsuleType.CAPSULE_TYPE_PROGRESS,
      status: 0,
      max: 100,
      progress: progress,
      content: progress >= 100 ? '已开门' : '开门中'
    };
    const primary: liveViewManager.PrimaryData = {
      title: title,
      content: content,
      keepTime: 8,
      layoutData: layout
    };
    return {
      id: 24001,
      event: EVENT,
      sequence: LiveViewService.sequence,
      isMute: true,
      liveViewData: {
        primary: primary,
        capsule: capsule
      }
    };
  }
}
