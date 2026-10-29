/**
 * Plain data objects shared by the UI, the network client and the BLE layer.
 * No secrets are logged or serialized for diagnostics.
 */

export class AccountRecord {
  username: string = '';
  passwordMd5: string = '';

  constructor(username: string, passwordMd5: string) {
    this.username = username;
    this.passwordMd5 = passwordMd5;
  }
}

export class SchoolInfo {
  schoolNo: string = '';
  name: string = '';
  serverUrl: string = '';
  token: string = '';

  constructor(schoolNo: string, name: string, serverUrl: string, token: string) {
    this.schoolNo = schoolNo;
    this.name = name;
    this.serverUrl = serverUrl;
    this.token = token;
  }
}

export class SessionInfo {
  userId: string = '';
  token: string = '';
  createdAt: number = 0;

  constructor(userId: string, token: string) {
    this.userId = userId;
    this.token = token;
    this.createdAt = Date.now();
  }
}

export const CAP_RESOLVED: string = 'RESOLVED';
export const CAP_OFFICIAL_NULL_AS_PLAIN: string = 'OFFICIAL_NULL_AS_PLAIN';
export const CAP_TYPE_ID_MISSING: string = 'TYPE_ID_MISSING';
export const CAP_TYPE_ID_INVALID: string = 'TYPE_ID_INVALID';
export const CAP_TYPE_NOT_IN_CATALOG: string = 'TYPE_NOT_IN_CATALOG';
export const CAP_AES_FIELD_MISSING: string = 'AES_FIELD_MISSING';
export const CAP_AES_FIELD_INVALID: string = 'AES_FIELD_INVALID';
export const CAP_CATALOG_CONFLICT: string = 'CATALOG_CONFLICT';

/**
 * A lock row resolved against the lock-type catalog. `aesKnown` is false when the
 * capability could not be proven; sending a frame is forbidden in that case.
 */
export class DoorLockInfo {
  label: string = '';
  lockNo: string = '';
  mac: string = '';
  serviceUuid: string = '';
  writeUuid: string = '';
  notifyUuid: string = '';
  secret: string = '';
  schoolNo: string = '';
  lockTypeId: number = -1;
  lockTypeIdKnown: boolean = false;
  aesSupport: boolean = false;
  aesKnown: boolean = false;
  capabilityStatus: string = '';
  capabilityFieldKind: string = '';
  blockedReason: string = '';

  constructor() {
  }

  get canUnlock(): boolean {
    return this.aesKnown && this.blockedReason.length === 0 && this.secret.length > 0
      && this.serviceUuid.length > 0 && this.writeUuid.length > 0;
  }
}

export enum UnlockKind {
  ACKNOWLEDGED = 0,
  KEY_REJECTED = 1,
  UNCONFIRMED = 2,
  UNSUPPORTED = 3,
  TRANSPORT_ERROR = 4,
  CANCELLED = 5
}

export class UnlockOutcome {
  kind: UnlockKind = UnlockKind.UNCONFIRMED;
  message: string = '';
  transportReachedLock: boolean = false;

  constructor(kind: UnlockKind, message: string, transportReachedLock: boolean) {
    this.kind = kind;
    this.message = message;
    this.transportReachedLock = transportReachedLock;
  }

  get isSuccess(): boolean {
    return this.kind === UnlockKind.ACKNOWLEDGED;
  }
}

export enum UnlockStage {
  PREPARING = 0,
  REFRESHING = 1,
  CONNECTING = 2,
  DISCOVERING = 3,
  SUBSCRIBING = 4,
  SENDING = 5,
  WAITING = 6,
  FINISHED = 7
}

export class StageUpdate {
  stage: UnlockStage = UnlockStage.PREPARING;
  text: string = '';
  detail: string = '';

  constructor(stage: UnlockStage, text: string, detail: string) {
    this.stage = stage;
    this.text = text;
    this.detail = detail;
  }
}

export class CardSnapshot {
  lockLabel: string = '未选择门锁';
  statusText: string = '在应用内登录并选择门锁';
  timeText: string = '';
  online: boolean = false;
  step: number = 0;
  busy: boolean = false;
  cardToken: string = '';
  homeOnA: boolean = true;
  animate: boolean = true;

  constructor(lockLabel: string, statusText: string, timeText: string, online: boolean,
    step: number = 0, busy: boolean = false, cardToken: string = '', homeOnA: boolean = true,
    animate: boolean = true) {
    this.lockLabel = lockLabel;
    this.statusText = statusText;
    this.timeText = timeText;
    this.online = online;
    this.step = step;
    this.busy = busy;
    this.cardToken = cardToken;
    this.homeOnA = homeOnA;
    this.animate = animate;
  }
}

export class CardFormRecord {
  formId: string = '';
  formName: string = '';

  constructor(formId: string, formName: string) {
    this.formId = formId;
    this.formName = formName;
  }
}
