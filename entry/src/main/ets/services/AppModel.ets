import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AccountRecord, CardSnapshot, DoorLockInfo, SchoolInfo, SessionInfo, UnlockKind, UnlockOutcome, UnlockStage, StageUpdate } from '../model/Models';
import { BleUnlockService, ProgressCallback } from './BleUnlockService';
import { CardUpdater } from './CardUpdater';
import { CardRegistry } from './CardRegistry';
import { md5Hex } from './Hash';
import { Prefs } from './Prefs';
import { YunmeiApi } from './YunmeiApi';
import { delay } from './AsyncUtil';

function shortText(text: string, limit: number): string {
  if (text.length <= limit) {
    return text;
  }
  return text.substring(0, limit - 1) + '…';
}

function clockText(): string {
  const now = new Date();
  const hour = now.getHours();
  const minute = now.getMinutes();
  return (hour < 10 ? '0' : '') + hour.toString() + ':' + (minute < 10 ? '0' : '') + minute.toString();
}

function isAuthError(message: string): boolean {
  return message.indexOf('登录状态已失效') >= 0
    || message.indexOf('登录或授权已失效') >= 0
    || message.indexOf('重新登录') >= 0;
}

function isTransientError(message: string): boolean {
  return message.indexOf('网络请求失败') >= 0
    || message.indexOf('网络连接失败') >= 0
    || message.indexOf('超时') >= 0
    || message.indexOf('响应格式') >= 0
    || message.indexOf('数据包装层级') >= 0;
}

/** Session and lock state shared by the page, the card updater and the BLE layer. */
export class AppModel {
  static readonly shared: AppModel = new AppModel();

  private prefs: Prefs = new Prefs();
  private context: common.Context | null = null;

  account: AccountRecord | null = null;
  session: SessionInfo | null = null;
  schools: SchoolInfo[] = [];
  school: SchoolInfo | null = null;
  locks: DoorLockInfo[] = [];
  lock: DoorLockInfo | null = null;
  remember: boolean = true;
  lastStatus: string = '';
  lastTime: string = '';
  lastError: string = '';
  lastStep: number = 0;
  lastBusy: boolean = false;
  lastRefreshWarning: string = '';
  cardToken: string = '';
  homeOnA: boolean = true;
  autoUnlockOnOpen: boolean = false;
  private lastAnim: boolean = true;
  private unlockCancelled: boolean = false;
  private lockFetchedAt: number = 0;

  async init(context: common.Context): Promise<void> {
    this.context = context;
    await this.prefs.init(context);
    const username = this.prefs.getString('username', '');
    const passwordMd5 = this.prefs.getString('passwordMd5', '');
    if (username.length > 0 && passwordMd5.length === 32) {
      this.account = new AccountRecord(username, passwordMd5);
    }
    this.remember = this.prefs.getBoolean('remember', true);
    this.homeOnA = true;
    this.autoUnlockOnOpen = this.prefs.getBoolean('auto_unlock_on_open', false);
    this.lastStatus = this.prefs.getString('card_status', '');
    this.lastTime = this.prefs.getString('card_time', '');
    // A random token is embedded in the cards; the exported headless ability
    // rejects calls that do not carry it.
    this.cardToken = this.prefs.getString('card_token', '');
    if (this.cardToken.length === 0) {
      this.cardToken = util.generateRandomUUID(true);
      await this.prefs.putString('card_token', this.cardToken);
    }
    CardRegistry.writeToken(context, this.cardToken);
    // A process restart means no unlock is running; never leave a card spinning.
    this.lastStep = 0;
    this.lastBusy = false;
  }

  verifyCardToken(token: string): boolean {
    return token.length > 0 && this.cardToken.length > 0 && token === this.cardToken;
  }

  async setAutoUnlockOnOpen(value: boolean): Promise<void> {
    this.autoUnlockOnOpen = value;
    await this.prefs.putBoolean('auto_unlock_on_open', value);
  }

  async toggleHomeColor(): Promise<void> {    this.homeOnA = !this.homeOnA;
    this.lastStep = 0;
    this.lastBusy = false;
    this.lastAnim = false;
    await this.prefs.putBoolean('home_on_a', this.homeOnA);
    await this.updateCard();
    this.lastAnim = true;
  }

  get isLoggedIn(): boolean {
    return this.session !== null && this.school !== null;
  }

  get savedUsername(): string {
    return this.account === null ? '' : this.account.username;
  }

  /** Silently logs back in with the saved account. Returns false when unavailable. */
  async restore(): Promise<boolean> {
    if (this.account === null) {
      return false;
    }
    try {
      await this.loginWithAccount(this.account);
      return true;
    } catch (error) {
      this.lastError = (error as Error).message;
      return false;
    }
  }

  async login(username: string, password: string, remember: boolean): Promise<void> {
    const name = username.trim();
    if (name.length === 0) {
      throw new Error('请输入 Cloessy 账号');
    }
    if (password.length === 0) {
      throw new Error('请输入登录密码');
    }
    const digest = md5Hex(password);
    const account = new AccountRecord(name, digest);
    this.remember = remember;
    await this.loginWithAccount(account);
    await this.prefs.putBoolean('remember', remember);
  }

  private async loginWithAccount(account: AccountRecord): Promise<void> {
    const session = await YunmeiApi.login(account);
    const schools = await YunmeiApi.fetchSchools(session);
    if (schools.length === 0) {
      throw new Error('此账号没有可用的学校授权，请在官方客户端确认');
    }
    const savedSchoolNo = this.prefs.getString('schoolNo', '');
    const school = AppModel.pickSchool(schools, savedSchoolNo);
    const locks = await YunmeiApi.fetchLocks(session, school);
    if (locks.length === 0) {
      throw new Error('此账号没有可用的门锁，请在官方客户端确认授权');
    }
    const savedLockNo = this.prefs.getString('lockNo', '');
    const lock = AppModel.pickLock(locks, savedLockNo);

    this.account = account;
    this.session = session;
    this.schools = schools;
    this.school = school;
    this.locks = locks;
    this.lock = lock;
    this.lockFetchedAt = Date.now();
    this.lastError = '';
    this.lastRefreshWarning = '';
    this.lastStep = 0;
    this.lastBusy = false;
    this.lastStatus = '轻触按钮开门';
    await this.persist();
    await this.updateCard();
  }

  /** Refreshes schools and locks with the current session (manual refresh). */
  async refreshAll(): Promise<void> {
    if (this.session === null) {
      throw new Error('请先登录 Cloessy 账号');
    }
    const session = this.session;
    const schools = await YunmeiApi.fetchSchools(session);
    if (schools.length === 0) {
      throw new Error('此账号没有可用的学校授权');
    }
    const currentSchoolNo = this.school === null ? '' : this.school.schoolNo;
    const school = AppModel.pickSchool(schools, currentSchoolNo);
    const locks = await YunmeiApi.fetchLocks(session, school);
    const currentLockNo = this.lock === null ? '' : this.lock.lockNo;
    const lock = AppModel.pickLock(locks, currentLockNo);
    this.schools = schools;
    this.school = school;
    this.locks = locks;
    this.lock = lock;
    this.lockFetchedAt = Date.now();
    this.lastRefreshWarning = '';
    await this.persist();
    await this.updateCard();
  }

  /**
   * Refreshes the lock right before OPEN. Reuses a recent session and a very
   * recent lock to cut network round trips; a transient network failure falls
   * back to the lock fetched in this process instead of blocking the door.
   */
  async refreshForUnlock(force: boolean = false): Promise<DoorLockInfo> {
    if (this.account === null) {
      throw new Error('请先登录 Cloessy 账号');
    }
    const sessionFresh = this.session !== null && Date.now() - this.session.createdAt < 8 * 60 * 1000;
    if (!force && sessionFresh && this.lock !== null && Date.now() - this.lockFetchedAt < 15000) {
    }
    try {
      const refreshed = await this.fetchFreshLock();
      this.lastRefreshWarning = '';
      return refreshed;
    } catch (error) {
      const message = (error as Error).message;
      if (this.lock !== null && this.lock.secret.length > 0 && this.lock.blockedReason.length === 0
        && Date.now() - this.lockFetchedAt < 90 * 1000
        && isTransientError(message)) {
        this.lastRefreshWarning = '网络异常，使用上次门锁凭据';
        return this.lock;
      }
      throw new Error(message);
    }
  }

  private async fetchFreshLock(): Promise<DoorLockInfo> {
    const account = this.account;
    if (account === null) {
      throw new Error('请先登录 Cloessy 账号');
    }
    let session: SessionInfo;
    let schools: SchoolInfo[];
    const existing = this.session;
    if (existing === null || Date.now() - existing.createdAt > 10 * 60 * 1000) {
      session = await YunmeiApi.login(account);
      schools = await YunmeiApi.fetchSchools(session);
    } else {
      session = existing;
      schools = this.schools;
      if (schools.length === 0) {
        schools = await YunmeiApi.fetchSchools(session);
      }
    }
    if (schools.length === 0) {
      throw new Error('此账号没有可用的学校授权');
    }
    const wantedSchool = this.school !== null ? this.school.schoolNo : this.prefs.getString('schoolNo', '');
    let school = AppModel.pickSchool(schools, wantedSchool);
    let locks: DoorLockInfo[] = [];
    try {
      locks = await YunmeiApi.fetchLocks(session, school);
    } catch (error) {
      const firstMessage = (error as Error).message;
      try {
        session = await YunmeiApi.login(account);
        schools = await YunmeiApi.fetchSchools(session);
        school = AppModel.pickSchool(schools, wantedSchool);
        locks = await YunmeiApi.fetchLocks(session, school);
      } catch (retryError) {
        throw new Error(firstMessage);
      }
    }
    if (locks.length === 0) {
      throw new Error('服务器未返回可用门锁');
    }
    const wantedLock = this.lock !== null ? this.lock.lockNo : this.prefs.getString('lockNo', '');
    let lock: DoorLockInfo | null = null;
    for (let i = 0; i < locks.length; i++) {
      if (locks[i].lockNo === wantedLock) {
        lock = locks[i];
        break;
      }
    }
    if (lock === null && locks.length === 1) {
      lock = locks[0];
    }
    if (lock === null) {
      throw new Error('服务器未返回上次选择的门锁，请重新选择');
    }
    this.account = account;
    this.session = session;
    this.schools = schools;
    this.school = school;
    this.locks = locks;
    this.lock = lock;
    this.lockFetchedAt = Date.now();
    await this.persist();
    return lock;
  }

  /**
   * Runs BLE OPEN up to three times. Transport failures retry with a scan-based
   * connection; a key rejection refreshes the credential before retrying.
   */
  cancelUnlock(): void {
    BleUnlockService.cancel();
  }

  async unlockWithRetry(onProgress: ProgressCallback): Promise<UnlockOutcome> {
    if (this.lock === null) {
      throw new Error('请先选择门锁');
    }
    let lastOutcome: UnlockOutcome | null = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      const currentLock = this.lock;
      if (currentLock === null) {
        break;
      }
      if (attempt > 0) {
        onProgress(new StageUpdate(UnlockStage.PREPARING, '正在重试开门',
          '第 ' + (attempt + 1) + ' 次尝试'));
        await delay(550);
      }
      if (this.lastRefreshWarning.length > 0) {
        onProgress(new StageUpdate(UnlockStage.PREPARING, this.lastRefreshWarning, '使用缓存凭据'));
        this.lastRefreshWarning = '';
      }
      const startedAt = Date.now();
      let preferScan: boolean = false;
      if (attempt === 1 && lastOutcome !== null) {
        preferScan = lastOutcome.kind === UnlockKind.TRANSPORT_ERROR && !lastOutcome.transportReachedLock;
      }
      try {
        let outcome: UnlockOutcome;
        outcome = await BleUnlockService.unlock(currentLock, onProgress, preferScan);
        lastOutcome = outcome;
        if (outcome.isSuccess) {
          return outcome;
        }
        if (outcome.kind === UnlockKind.UNSUPPORTED || outcome.kind === UnlockKind.CANCELLED) {
          return outcome;
        }
        if (attempt < 2) {
          try {
            await this.refreshForUnlock(true);
          } catch (error) {
          }
        }
      } catch (error) {
        lastOutcome = new UnlockOutcome(UnlockKind.TRANSPORT_ERROR, (error as Error).message, false);
      }
      // Do not stack several full timeouts; retry is useful only for quick failures.
      if (Date.now() - startedAt > 25000) {
        break;
      }
    }
    if (lastOutcome !== null) {
      return lastOutcome;
    }
    return new UnlockOutcome(UnlockKind.UNCONFIRMED, '开门结果未确认，请确认门锁实际状态', false);
  }

  async unlock(onProgress: ProgressCallback): Promise<UnlockOutcome> {
    const currentLock = this.lock;
    if (currentLock === null) {
      throw new Error('请先选择门锁');
    }
    return BleUnlockService.unlock(currentLock, onProgress, false);
  }

  async switchSchool(school: SchoolInfo): Promise<void> {
    if (this.session === null) {
      throw new Error('请先登录 Cloessy 账号');
    }
    const locks = await YunmeiApi.fetchLocks(this.session, school);
    this.school = school;
    this.locks = locks;
    this.lock = locks.length > 0 ? locks[0] : null;
    this.lastRefreshWarning = '';
    await this.persist();
    await this.updateCard();
  }

  async selectLock(lock: DoorLockInfo): Promise<void> {
    this.lock = lock;
    this.lastStep = 0;
    this.lastBusy = false;
    await this.persist();
    await this.updateCard();
  }

  async logout(): Promise<void> {
    this.account = null;
    this.session = null;
    this.schools = [];
    this.school = null;
    this.locks = [];
    this.lock = null;
    this.lastStatus = '';
    this.lastTime = '';
    this.lastError = '';
    this.lastStep = 0;
    this.lastBusy = false;
    this.lockFetchedAt = 0;
    await this.prefs.remove('username');
    await this.prefs.remove('passwordMd5');
    await this.prefs.remove('schoolNo');
    await this.prefs.remove('lockNo');
    await this.updateCard();
  }

  async recordOutcome(outcome: UnlockOutcome): Promise<void> {
    this.lastAnim = true;
    if (outcome.isSuccess) {
      this.lastStatus = '开门指令已确认';
      this.lastTime = clockText() + ' 已开门';
      this.lastStep = 5;
    } else {
      this.lastStatus = shortText(outcome.message, 30);
      this.lastTime = clockText() + ' 未确认';
      this.lastStep = -1;
    }
    this.lastBusy = false;
    await this.updateCard();
  }

  /** Progress feed for the desktop card (headless unlock and in-app unlock). */
  async setCardProgress(text: string, step: number, busy: boolean): Promise<void> {
    this.lastAnim = true;
    this.lastStatus = text;
    this.lastStep = step;
    this.lastBusy = busy;
    await this.updateCard();
  }

  async updateCard(): Promise<void> {
    if (this.context === null) {
      return;
    }
    const snapshot = this.cardSnapshot();
    await CardUpdater.update(this.context, snapshot);
  }

  cardSnapshot(): CardSnapshot {
    let label = '未选择门锁';
    if (this.lock !== null) {
      label = this.lock.label.length > 0 ? this.lock.label : this.lock.lockNo;
    }
    let status = '在应用内登录并选择门锁';
    if (this.lock !== null) {
      status = this.lastStatus.length > 0 ? this.lastStatus : '轻触按钮开门';
    }
    return new CardSnapshot(label, status, this.lastTime,
      this.session !== null && this.lock !== null, this.lastStep, this.lastBusy, this.cardToken,
      this.homeOnA, this.lastAnim);
  }

  private async persist(): Promise<void> {
    if (this.account !== null && this.remember) {
      await this.prefs.putString('username', this.account.username);
      await this.prefs.putString('passwordMd5', this.account.passwordMd5);
    } else if (!this.remember) {
      await this.prefs.remove('username');
      await this.prefs.remove('passwordMd5');
    }
    if (this.school !== null) {
      await this.prefs.putString('schoolNo', this.school.schoolNo);
    }
    if (this.lock !== null) {
      await this.prefs.putString('lockNo', this.lock.lockNo);
    }
  }

  private static pickSchool(schools: SchoolInfo[], wantedNo: string): SchoolInfo {
    for (let i = 0; i < schools.length; i++) {
      if (schools[i].schoolNo === wantedNo) {
        return schools[i];
      }
    }
    return schools[0];
  }

  private static pickLock(locks: DoorLockInfo[], wantedNo: string): DoorLockInfo {
    for (let i = 0; i < locks.length; i++) {
      if (locks[i].lockNo === wantedNo) {
        return locks[i];
      }
    }
    return locks[0];
  }
}
