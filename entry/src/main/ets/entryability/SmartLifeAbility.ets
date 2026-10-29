import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SmartLifeService } from '../services/SmartLifeService';

const DOMAIN = 0x1212;
const TAG = 'CloessySmartLife';

/**
 * Invisible target for the Smart Life shortcut / app-service action.
 * The shortcut passes action=unlock and source=smartlife.
 */
export default class SmartLifeAbility extends UIAbility {
  private started: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'smart life ability created');
    this.start(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.start(want);
  }

  onWindowStageCreate(): void {
    // No content: this ability is only a background trigger.
  }

  private start(want: Want): void {
    if (this.started) {
      return;
    }
    const params = want.parameters;
    const action = params === undefined ? undefined : params['action'];
    const source = params === undefined ? undefined : params['source'];
    if (action !== 'unlock' || source !== 'smartlife') {
      hilog.warn(DOMAIN, TAG, 'ignored non-unlock want');
      this.context.terminateSelf().catch(() => {
      });
      return;
    }
    this.started = true;
    SmartLifeService.run(this.context).then(() => {
      this.context.terminateSelf().catch(() => {
      });
    }).catch(() => {
      this.context.terminateSelf().catch(() => {
      });
    });
  }
}
