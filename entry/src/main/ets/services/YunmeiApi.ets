import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccountRecord, DoorLockInfo, SchoolInfo, SessionInfo } from '../model/Models';
import { LockCapabilities } from './LockCapabilities';
import {
  arrayPayload,
  asRecord,
  exactField,
  failureMessage,
  hasField,
  JsonRecord,
  objectWithField,
  parseJson,
  textField
} from './JsonUtil';

const BASE_URL: string = 'https://base.yunmeitech.com/';
const DOMAIN: number = 0x1203;
const TAG: string = 'YunmeiApi';
const UUID_PATTERN = new RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
const MAC_PATTERN = new RegExp('^([0-9A-F]{2}:){5}[0-9A-F]{2}$');

function firstField(record: JsonRecord | null, keys: string[]): string {
  for (let i = 0; i < keys.length; i++) {
    const value = textField(record, keys[i]);
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function firstExact(record: JsonRecord | null, keys: string[]): string {
  for (let i = 0; i < keys.length; i++) {
    const value = exactField(record, keys[i]);
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function rejectionMessage(operation: string, raw: string): string {
  if (raw.indexOf('人脸') >= 0) {
    return '服务器要求完成人脸验证，请在官方客户端处理后重试。';
  }
  if (raw.indexOf('设备') >= 0) {
    return '服务器拒绝当前设备状态，请在官方客户端确认设备绑定。';
  }
  if (raw.indexOf('未登录') >= 0 || raw.indexOf('过期') >= 0 || raw.indexOf('失效') >= 0) {
    return '登录或授权已失效，请重新登录。';
  }
  if (raw.indexOf('密码') >= 0 || raw.indexOf('账号') >= 0 || raw.indexOf('用户不存在') >= 0) {
    return '服务器拒绝账号凭据，请检查账号与密码。';
  }
  if (raw.indexOf('权限') >= 0 || raw.indexOf('停用') >= 0 || raw.indexOf('绑定') >= 0) {
    return '服务器拒绝此账号的当前授权，请在官方客户端确认。';
  }
  return '服务器拒绝' + operation + '，请确认账号与门锁授权。';
}

export class YunmeiApi {
  static async login(account: AccountRecord): Promise<SessionInfo> {
    if (account.username.trim().length === 0 || account.passwordMd5.length !== 32) {
      throw new Error('账号信息不完整，无法登录。');
    }
    const fields = new Map<string, string>();
    fields.set('userName', account.username.trim());
    fields.set('userPwd', account.passwordMd5.toLowerCase());
    const payload = await YunmeiApi.post(BASE_URL, 'login', '', '', fields, '登录');
    const object = objectWithField(payload, 'token', 0);
    if (object === null) {
      throw new Error('登录响应缺少会话信息，暂时无法继续。');
    }
    const userId = firstField(object, ['userId', 'id']);
    const token = textField(object, 'token');
    if (userId.length === 0 || token.length === 0) {
      throw new Error('登录响应缺少会话信息，暂时无法继续。');
    }
    return new SessionInfo(userId, token);
  }

  static async fetchSchools(session: SessionInfo): Promise<SchoolInfo[]> {
    const fields = new Map<string, string>();
    fields.set('userId', session.userId);
    const payload = await YunmeiApi.post(BASE_URL, 'userschool/getbyuserid', session.userId,
      session.token, fields, '获取学校');
    const rows = arrayPayload(payload, 0);
    if (rows === null) {
      throw new Error('获取学校响应缺少有效列表。');
    }
    const schools: SchoolInfo[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = asRecord(rows[i]);
      if (row === null) {
        throw new Error('学校列表含无法识别的数据项。');
      }
      const nested = asRecord(row['school'] as Object);
      const schoolNo = firstField(row, ['schoolNo']);
      const nestedNo = nested === null ? '' : firstField(nested, ['schoolNo']);
      const number = schoolNo.length > 0 ? schoolNo : nestedNo;
      const name = nested !== null ? firstField(nested, ['schoolName', 'name']) : '';
      const fallbackName = firstField(row, ['schoolName', 'name']);
      const displayName = name.length > 0 ? name : (fallbackName.length > 0 ? fallbackName : number);
      const serverUrl = nested !== null && firstField(nested, ['serverUrl']).length > 0
        ? firstField(nested, ['serverUrl']) : firstField(row, ['serverUrl']);
      const token = textField(row, 'token');
      if (number.length === 0 || serverUrl.length === 0 || token.length === 0) {
        throw new Error('学校响应缺少服务器或授权信息，请重新登录。');
      }
      schools.push(new SchoolInfo(number, displayName, serverUrl, token));
    }
    return schools;
  }

  static async fetchLocks(session: SessionInfo, school: SchoolInfo): Promise<DoorLockInfo[]> {
    const typeFields = new Map<string, string>();
    const catalogPayload = await YunmeiApi.post(BASE_URL, 'locktype/all', session.userId,
      session.token, typeFields, '获取门锁类型');
    const typeRows = arrayPayload(catalogPayload, 0);
    if (typeRows === null) {
      throw new Error('获取门锁类型响应缺少有效列表。');
    }
    const capabilities = new LockCapabilities();
    for (let i = 0; i < typeRows.length; i++) {
      const type = asRecord(typeRows[i]);
      if (type === null) {
        continue;
      }
      capabilities.add(type['id'] as Object, hasField(type, 'aesSupport'),
        hasField(type, 'aesSupport') ? (type['aesSupport'] as Object) : null);
    }

    const fields = new Map<string, string>();
    fields.set('schoolNo', school.schoolNo);
    fields.set('userId', session.userId);
    const payload = await YunmeiApi.post(school.serverUrl, 'dormuser/getuserlock', session.userId,
      school.token, fields, '获取门锁');
    const rows = arrayPayload(payload, 0);
    if (rows === null) {
      throw new Error('获取门锁响应缺少有效列表。');
    }
    const locks: DoorLockInfo[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = asRecord(rows[i]);
      if (row === null) {
        throw new Error('门锁列表含无法识别的数据项。');
      }
      const lockNo = textField(row, 'lockNo');
      if (lockNo.length === 0) {
        throw new Error('门锁列表缺少设备标识，暂时无法使用。');
      }
      const returnedSchool = textField(row, 'schoolNo');
      if (returnedSchool.length > 0 && returnedSchool !== school.schoolNo) {
        throw new Error('服务器返回了其他学校的门锁，已停止本次操作。');
      }

      const resolution = capabilities.resolve(hasField(row, 'lockTypeId'),
        hasField(row, 'lockTypeId') ? (row['lockTypeId'] as Object) : null);

      const lock = new DoorLockInfo();
      lock.lockNo = lockNo;
      const rawMac = firstField(row, ['lockMac', 'mac']);
      const macCandidate = rawMac.length > 0 ? rawMac : (MAC_PATTERN.test(lockNo.toUpperCase()) ? lockNo : '');
      lock.mac = macCandidate.toUpperCase();
      lock.schoolNo = school.schoolNo;
      lock.lockTypeId = resolution.typeId;
      lock.lockTypeIdKnown = resolution.typeIdKnown;
      lock.aesSupport = resolution.aesSupport;
      lock.aesKnown = resolution.aesKnown;
      lock.capabilityStatus = resolution.status;
      lock.capabilityFieldKind = resolution.fieldKind;
      lock.secret = firstExact(row, ['lockSecret', 'secret']);

      let serviceUuid = firstField(row, ['lockServiceUuid', 'serviceUuid']).toLowerCase();
      let writeUuid = firstField(row, ['lockCharacterUuid', 'characteristicUuid', 'writeUuid']).toLowerCase();
      let notifyUuid = firstField(row, ['lockCharacterUuid1', 'characteristicUuid1', 'notifyUuid']).toLowerCase();
      if (notifyUuid.length === 0 && writeUuid.indexOf('6e400002-') === 0) {
        notifyUuid = '6e400003-' + writeUuid.substring(9);
      }
      lock.serviceUuid = serviceUuid;
      lock.writeUuid = writeUuid;
      lock.notifyUuid = notifyUuid;

      const label = firstField(row, ['label']);
      const building = firstField(row, ['buildName']);
      const dorm = firstField(row, ['dormNo']);
      let display = label;
      if (display.length === 0) {
        if (building.length > 0 && dorm.length > 0) {
          display = building + '-' + dorm;
        } else if (building.length > 0) {
          display = building;
        } else if (dorm.length > 0) {
          display = dorm;
        } else {
          display = lockNo;
        }
      }
      lock.label = display;

      if (!resolution.aesKnown) {
        lock.blockedReason = LockCapabilities.message(resolution.status);
      } else if (lock.secret.length === 0) {
        lock.blockedReason = '门锁未返回密钥，暂不能发送开锁指令';
      } else if (!UUID_PATTERN.test(serviceUuid) || !UUID_PATTERN.test(writeUuid)) {
        lock.blockedReason = '门锁蓝牙服务或写入特征信息不完整';
      } else if (!UUID_PATTERN.test(notifyUuid)) {
        lock.blockedReason = '缺少已知通知特征信息，暂不能确认开门结果';
      } else {
        lock.blockedReason = '';
      }
      locks.push(lock);
    }
    return locks;
  }

  private static async post(baseUrl: string, route: string, userId: string, token: string,
    fields: Map<string, string>, operation: string): Promise<Object> {
    const url = YunmeiApi.endpoint(baseUrl, route);
    if (userId.indexOf('\n') >= 0 || userId.indexOf('\r') >= 0
      || token.indexOf('\n') >= 0 || token.indexOf('\r') >= 0) {
      throw new Error('授权信息格式不正确，请重新登录。');
    }
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Accept': 'application/json',
      'x-requested-with': 'XMLHttpRequest'
    };
    if (userId.length > 0) {
      headers['token_userId'] = userId;
      headers['tokenUserId'] = userId;
    }
    if (token.length > 0) {
      headers['token_data'] = token;
      headers['tokenData'] = token;
    }
    const request = http.createHttp();
    let status = 0;
    let text = '';
    const body = YunmeiApi.encodeForm(fields);
    // ohos.net.http rejects an empty extraData string with error 401, so a POST
    // without form fields (locktype/all) carries a harmless marker field that
    // the service ignores. Verified against the live endpoint.
    const requestBody = body.length > 0 ? body : 'harmony=1';
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: requestBody,
      connectTimeout: 15000,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false
    };
    try {
      const response = await request.request(url, options);
      status = response.responseCode;
      if (typeof response.result === 'string') {
        text = response.result;
      }
    } catch (error) {
      const business = error as BusinessError;
      const code = business.code === undefined ? -1 : business.code;
      hilog.error(DOMAIN, TAG, '%{public}s network error, code=%{public}d', operation, code);
      throw new Error(operation + '网络请求失败，请检查网络后重试。');
    } finally {
      request.destroy();
    }
    if (status === 401) {
      throw new Error('登录状态已失效，请重新登录。');
    }
    if (status === 403) {
      throw new Error('服务器拒绝此账号执行该操作，请确认授权。');
    }
    if (status >= 300 && status < 400) {
      throw new Error('服务器地址发生跳转，请重新获取学校信息。');
    }
    if (status < 200 || status >= 300) {
      throw new Error(operation + '请求失败（HTTP ' + status + '），请稍后重试。');
    }
    if (text.startsWith('\ufeff')) {
      text = text.substring(1);
    }
    const parsed = parseJson(text);
    if (parsed === null) {
      throw new Error('服务器响应格式不受支持，暂时无法完成' + operation + '。');
    }
    const failure = failureMessage(parsed, 0);
    if (failure.length > 0) {
      throw new Error(rejectionMessage(operation, failure));
    }
    return parsed;
  }

  private static endpoint(baseUrl: string, route: string): string {
    const base = baseUrl.trim();
    if (base.toLowerCase().indexOf('https://') !== 0) {
      throw new Error('服务未提供 HTTPS 地址，暂不发送账号或门锁凭据。');
    }
    const normalized = base.endsWith('/') ? base : base + '/';
    return normalized + route;
  }

  private static encodeForm(fields: Map<string, string>): string {
    const parts: string[] = [];
    fields.forEach((value: string, key: string) => {
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
    });
    return parts.join('&');
  }
}
