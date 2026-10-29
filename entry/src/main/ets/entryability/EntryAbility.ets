import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x1201;
const TAG = 'YunmeiEntry';

/** Converts a card/ability Want into the shared launch action consumed by the page. */
function readLaunchAction(want: Want): string {
  const params = want.parameters;
  if (params === undefined) {
    return '';
  }
  const action = params['action'];
  const source = params['source'];
  if (action === 'unlock' && source === 'smartlife') {
    return 'smartlifeUnlock';
  }
  const value = params['yunmeiAction'];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

/** Monotonic per-process tick so two card taps in the same millisecond are distinct. */
function nextLaunchTick(): number {
  const current = AppStorage.get<number>('launchTick');
  return (current === undefined ? 0 : current) + 1;
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string>('launchAction', readLaunchAction(want));
    AppStorage.setOrCreate<number>('launchTick', nextLaunchTick());
    hilog.info(DOMAIN, TAG, 'onCreate, action=%{public}s', readLaunchAction(want));
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string>('launchAction', readLaunchAction(want));
    AppStorage.setOrCreate<number>('launchTick', nextLaunchTick());
    hilog.info(DOMAIN, TAG, 'onNewWant, action=%{public}s', readLaunchAction(want));
  }

  onForeground(): void {
    const current = AppStorage.get<number>('appForegroundTick');
    AppStorage.setOrCreate<number>('appForegroundTick', (current === undefined ? 0 : current) + 1);
    hilog.info(DOMAIN, TAG, 'onForeground tick=%{public}d', (current === undefined ? 0 : current) + 1);
  }
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/CloessyHome', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true).catch(() => {
      });
      mainWindow.setWindowSystemBarEnable([]).catch(() => {
      });
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#171D29',
        statusBarContentColor: '#E9E4DA',
        navigationBarColor: '#171D29',
        navigationBarContentColor: '#E9E4DA'
      }).catch(() => {
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'system bar setup skipped');
    }
  }
}
