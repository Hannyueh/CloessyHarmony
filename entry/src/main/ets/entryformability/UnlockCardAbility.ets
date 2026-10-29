import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { STORE_NAME } from '../services/Prefs';
import { CardRegistry } from '../services/CardRegistry';

const DOMAIN = 0x1202;
const TAG = 'YunmeiCard';

function readString(store: preferences.Preferences, key: string, fallback: string): string {
  const value = store.getSync(key, fallback);
  return typeof value === 'string' ? value : fallback;
}

function readBoolean(store: preferences.Preferences, key: string, fallback: boolean): boolean {
  const value = store.getSync(key, fallback);
  return typeof value === 'boolean' ? value : fallback;
}

function readNumber(store: preferences.Preferences, key: string, fallback: number): number {
  const value = store.getSync(key, fallback);
  return typeof value === 'number' ? value : fallback;
}

export default class UnlockCardAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const params = want.parameters;
    let formId = '';
    let formName = '';
    let wide = false;
    if (params !== undefined) {
      const idValue = params['ohos.extra.param.key.form_identity'];
      if (typeof idValue === 'string') {
        formId = idValue;
      } else if (typeof idValue === 'number') {
        formId = idValue.toString();
      }
      const nameValue = params['ohos.extra.param.key.form_name'];
      if (typeof nameValue === 'string') {
        formName = nameValue;
      }
      const dimension = params['ohos.extra.param.key.form_dimension'];
      wide = dimension === 3 || dimension === '3';
    }
    hilog.info(DOMAIN, TAG, 'onAddForm %{public}s %{public}s', formId, formName);
    CardRegistry.add(this.context, formId, formName);
    setTimeout(() => {
      this.refreshCard(formId);
    }, 300);
    return formBindingData.createFormBindingData({
      'lockLabel': '未选择门锁',
      'statusText': '在应用内登录并选择门锁',
      'timeText': '',
      'online': false,
      'step': 0,
      'busy': false,
      'cardToken': '',
      'homeOnA': true,
      'animate': true,
      'wide': wide
    });
  }

  onRemoveForm(formId: string): void {
    CardRegistry.remove(this.context, formId);
  }

  private async refreshCard(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    try {
      const store = await preferences.getPreferences(this.context, STORE_NAME);
      let token = CardRegistry.readToken(this.context);
      if (token.length === 0) {
        token = readString(store, 'card_token', '');
      }
      const data: Record<string, Object> = {
        'lockLabel': readString(store, 'lock_label', '未选择门锁'),
        'statusText': readString(store, 'card_status', '在应用内登录并选择门锁'),
        'timeText': readString(store, 'card_time', ''),
        'online': readBoolean(store, 'card_online', false),
        'step': readNumber(store, 'card_step', 0),
        'busy': readBoolean(store, 'card_busy', false),
        'cardToken': token,
        'homeOnA': readBoolean(store, 'home_on_a', true),
        'animate': readBoolean(store, 'card_anim', true)
      };
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'refreshCard failed');
    }
  }
}
