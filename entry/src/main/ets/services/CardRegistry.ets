import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { CardFormRecord } from '../model/Models';

/**
 * Form IDs are shared by the app process and the FormExtension process. A small
 * JSON file in filesDir is reliable across processes, unlike process-cached
 * preferences, and lets a background ability update the card.
 */
export class CardRegistry {
  private static readonly FILE_NAME: string = 'card_forms.json';
  private static readonly TOKEN_FILE: string = 'card_token.txt';

  private static path(context: common.Context): string {
    return context.filesDir + '/' + CardRegistry.FILE_NAME;
  }

  /** The card token must be readable from the form process as well. */
  static readToken(context: common.Context): string {
    try {
      const path = context.filesDir + '/' + CardRegistry.TOKEN_FILE;
      if (!fileIo.accessSync(path)) {
        return '';
      }
      return fileIo.readTextSync(path).trim();
    } catch (error) {
      return '';
    }
  }

  static writeToken(context: common.Context, token: string): void {
    try {
      const path = context.filesDir + '/' + CardRegistry.TOKEN_FILE;
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, token);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
    }
  }

  static read(context: common.Context): CardFormRecord[] {
    try {
      const path = CardRegistry.path(context);
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const text = fileIo.readTextSync(path);
      if (text.length === 0) {
        return [];
      }
      const parsed = JSON.parse(text) as CardFormRecord[];
      if (Array.isArray(parsed)) {
        return parsed;
      }
      return [];
    } catch (error) {
      return [];
    }
  }

  static add(context: common.Context, formId: string, formName: string): void {
    if (formId.length === 0) {
      return;
    }
    const records = CardRegistry.read(context).filter((item: CardFormRecord) => item.formId !== formId);
    records.push(new CardFormRecord(formId, formName));
    CardRegistry.write(context, records);
  }

  static remove(context: common.Context, formId: string): void {
    const records = CardRegistry.read(context).filter((item: CardFormRecord) => item.formId !== formId);
    CardRegistry.write(context, records);
  }

  private static write(context: common.Context, records: CardFormRecord[]): void {
    try {
      const path = CardRegistry.path(context);
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, JSON.stringify(records));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
    }
  }
}
