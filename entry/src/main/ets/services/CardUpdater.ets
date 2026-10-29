import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CardSnapshot, CardFormRecord } from '../model/Models';
import { STORE_NAME } from './Prefs';
import { CardRegistry } from './CardRegistry';

/** Pushes lock label, status and progress to every card the user added. */
export class CardUpdater {
  // Progress updates and the final result must not overtake each other.
  private static chain: Promise<void> = Promise.resolve();

  static update(context: common.Context, snapshot: CardSnapshot): Promise<void> {
    const next = CardUpdater.chain.then(() => CardUpdater.doUpdate(context, snapshot));
    CardUpdater.chain = next.catch(() => {
    });
    return next;
  }

  private static async doUpdate(context: common.Context, snapshot: CardSnapshot): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME);
      store.putSync('lock_label', snapshot.lockLabel);
      store.putSync('card_status', snapshot.statusText);
      store.putSync('card_time', snapshot.timeText);
      store.putSync('card_online', snapshot.online);
      store.putSync('card_step', snapshot.step);
      store.putSync('card_busy', snapshot.busy);
      store.putSync('home_on_a', snapshot.homeOnA);
      store.putSync('card_anim', snapshot.animate);
      await store.flush();

      const records = CardUpdater.collectRecords(context, store);
      const data: Record<string, Object> = {
        'lockLabel': snapshot.lockLabel,
        'statusText': snapshot.statusText,
        'timeText': snapshot.timeText,
        'online': snapshot.online,
        'step': snapshot.step,
        'busy': snapshot.busy,
        'cardToken': snapshot.cardToken,
        'homeOnA': snapshot.homeOnA,
        'animate': snapshot.animate
      };
      for (let i = 0; i < records.length; i++) {
        const record = records[i];
        if (record.formId === undefined || record.formId.length === 0) {
          continue;
        }
        try {
          await formProvider.updateForm(record.formId, formBindingData.createFormBindingData(data));
        } catch (error) {
        }
      }
    } catch (error) {
    }
  }

  /** File registry is cross-process; preferences keep cards added before the update. */
  private static collectRecords(context: common.Context, store: preferences.Preferences): CardFormRecord[] {
    const merged: CardFormRecord[] = [];
    const seen: string[] = [];
    const fromFile = CardRegistry.read(context);
    for (let i = 0; i < fromFile.length; i++) {
      const record = fromFile[i];
      if (record.formId !== undefined && record.formId.length > 0) {
        merged.push(record);
        seen.push(record.formId);
      }
    }
    try {
      const raw = store.getSync('card_forms', '[]') as string;
      const fromPrefs = JSON.parse(raw) as CardFormRecord[];
      for (let i = 0; i < fromPrefs.length; i++) {
        const record = fromPrefs[i];
        if (record.formId !== undefined && record.formId.length > 0 && seen.indexOf(record.formId) < 0) {
          merged.push(record);
          seen.push(record.formId);
        }
      }
    } catch (error) {
    }
    return merged;
  }
}
