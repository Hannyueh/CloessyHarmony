import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const STORE_NAME: string = 'yunmei_prefs';

/** Local preferences. The user explicitly accepted plain local storage for the account. */
export class Prefs {
  private store: preferences.Preferences | null = null;

  async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, STORE_NAME);
  }

  getString(key: string, fallback: string): string {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'string' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  getBoolean(key: string, fallback: boolean): boolean {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'boolean' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  getNumber(key: string, fallback: number): number {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'number' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  async putString(key: string, value: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync(key, value);
      await this.store.flush();
    } catch (error) {
    }
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync(key, value);
      await this.store.flush();
    } catch (error) {
    }
  }

  async putNumber(key: string, value: number): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync(key, value);
      await this.store.flush();
    } catch (error) {
    }
  }

  async remove(key: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      this.store.deleteSync(key);
      await this.store.flush();
    } catch (error) {
    }
  }
}
