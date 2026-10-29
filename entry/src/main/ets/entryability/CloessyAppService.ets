import { AppServiceExtensionAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rpc } from '@kit.IPCKit';

const DOMAIN = 0x1213;
const TAG = 'CloessyAppService';

/**
 * App-service entry for scene platforms. It forwards an unlock request to the
 * headless SmartLifeAbility. Smart Life discovery/entitlement is controlled by
 * Huawei's scene platform; the shortcut entry is the primary test path.
 */
export default class CloessyAppService extends AppServiceExtensionAbility {
  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'app service created');
  }

  onRequest(want: Want, startId: number): void {
    const params = want.parameters;
    const action = params === undefined ? undefined : params['action'];
    if (action !== 'unlock' && action !== 'open') {
      return;
    }
    const bundleName = this.context.applicationInfo.name;
    this.context.startAbility({
      bundleName: bundleName,
      moduleName: 'entry',
      abilityName: 'SmartLifeAbility',
      parameters: {
        'action': 'unlock',
        'source': 'smartlife'
      }
    }).catch(() => {
      hilog.warn(DOMAIN, TAG, 'forward unlock failed');
    });
  }

  onDisconnect(want: Want): void {
  }

  onConnect(want: Want): rpc.RemoteObject {
    return new rpc.RemoteObject('CloessyAppService');
  }
}
