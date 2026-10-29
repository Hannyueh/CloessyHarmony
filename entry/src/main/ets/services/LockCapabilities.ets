import {
  CAP_AES_FIELD_INVALID,
  CAP_AES_FIELD_MISSING,
  CAP_CATALOG_CONFLICT,
  CAP_OFFICIAL_NULL_AS_PLAIN,
  CAP_RESOLVED,
  CAP_TYPE_ID_INVALID,
  CAP_TYPE_ID_MISSING,
  CAP_TYPE_NOT_IN_CATALOG
} from '../model/Models';

export const FIELD_MISSING: string = 'MISSING';
export const FIELD_NULL: string = 'NULL';
export const FIELD_BOOLEAN: string = 'BOOLEAN';
export const FIELD_NUMBER: string = 'NUMBER';
export const FIELD_STRING: string = 'STRING';
export const FIELD_OTHER: string = 'OTHER';
export const FIELD_CONFLICT: string = 'CONFLICT';

export class CapabilityResolution {
  typeId: number = -1;
  typeIdKnown: boolean = false;
  aesSupport: boolean = false;
  aesKnown: boolean = false;
  status: string = CAP_TYPE_ID_MISSING;
  fieldKind: string = FIELD_MISSING;

  constructor(typeId: number, typeIdKnown: boolean, aesSupport: boolean, aesKnown: boolean,
    status: string, fieldKind: string) {
    this.typeId = typeId;
    this.typeIdKnown = typeIdKnown;
    this.aesSupport = aesSupport;
    this.aesKnown = aesKnown;
    this.status = status;
    this.fieldKind = fieldKind;
  }
}

function numericValue(value: Object | null): number | null {
  if (value === null) {
    return null;
  }
  let numberValue = NaN;
  if (typeof value === 'number') {
    numberValue = value;
  } else if (typeof value === 'string') {
    const text = value.trim();
    if (text.length === 0 || text.length > 64) {
      return null;
    }
    numberValue = Number(text);
  } else {
    return null;
  }
  if (!Number.isFinite(numberValue) || !Number.isInteger(numberValue)) {
    return null;
  }
  return numberValue;
}

function aesValue(value: Object | null): boolean | null {
  if (value === null) {
    return null;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const text = value.trim();
    if (text === 'true') {
      return true;
    }
    if (text === 'false') {
      return false;
    }
  }
  const numberValue = numericValue(value);
  if (numberValue === null) {
    return null;
  }
  if (numberValue === 0) {
    return false;
  }
  if (numberValue === 1) {
    return true;
  }
  return null;
}

/**
 * Resolves `aesSupport` from the type catalog with provenance. Explicit null is
 * accepted as plain framing only because the official module checks `== 1`;
 * a missing field, an absent type or an invalid value still blocks sending.
 */
export class LockCapabilities {
  private catalog: Map<number, CapabilityResolution> = new Map<number, CapabilityResolution>();
  private invalidIdRows: number = 0;

  get validTypeCount(): number {
    return this.catalog.size;
  }

  get invalidRows(): number {
    return this.invalidIdRows;
  }

  add(idValue: Object | null, aesPresent: boolean, aesValueRaw: Object | null): void {
    const id = numericValue(idValue);
    if (id === null) {
      this.invalidIdRows++;
      return;
    }
    let fieldKind = FIELD_OTHER;
    if (!aesPresent) {
      fieldKind = FIELD_MISSING;
    } else if (aesValueRaw === null) {
      fieldKind = FIELD_NULL;
    } else if (typeof aesValueRaw === 'boolean') {
      fieldKind = FIELD_BOOLEAN;
    } else if (typeof aesValueRaw === 'number') {
      fieldKind = FIELD_NUMBER;
    } else if (typeof aesValueRaw === 'string') {
      fieldKind = FIELD_STRING;
    }

    let resolution: CapabilityResolution;
    if (!aesPresent) {
      resolution = new CapabilityResolution(id, true, false, false, CAP_AES_FIELD_MISSING, fieldKind);
    } else if (aesValueRaw === null) {
      resolution = new CapabilityResolution(id, true, false, true, CAP_OFFICIAL_NULL_AS_PLAIN, FIELD_NULL);
    } else {
      const aes = aesValue(aesValueRaw);
      if (aes === null) {
        resolution = new CapabilityResolution(id, true, false, false, CAP_AES_FIELD_INVALID, fieldKind);
      } else {
        resolution = new CapabilityResolution(id, true, aes, true, CAP_RESOLVED, fieldKind);
      }
    }

    const previous = this.catalog.get(id);
    if (previous !== undefined
      && (previous.status === CAP_CATALOG_CONFLICT
        || previous.status !== resolution.status
        || previous.aesSupport !== resolution.aesSupport)) {
      resolution = new CapabilityResolution(id, true, false, false, CAP_CATALOG_CONFLICT, FIELD_CONFLICT);
    }
    this.catalog.set(id, resolution);
  }

  resolve(idPresent: boolean, idValue: Object | null): CapabilityResolution {
    if (!idPresent || idValue === null) {
      return new CapabilityResolution(-1, false, false, false, CAP_TYPE_ID_MISSING, FIELD_MISSING);
    }
    const id = numericValue(idValue);
    if (id === null) {
      return new CapabilityResolution(-1, false, false, false, CAP_TYPE_ID_INVALID, FIELD_MISSING);
    }
    const found = this.catalog.get(id);
    if (found === undefined) {
      return new CapabilityResolution(id, true, false, false, CAP_TYPE_NOT_IN_CATALOG, FIELD_MISSING);
    }
    return found;
  }

  static message(status: string): string {
    if (status === CAP_OFFICIAL_NULL_AS_PLAIN) {
      return '按官方空值规则使用普通协议';
    }
    if (status === CAP_TYPE_ID_MISSING) {
      return '门锁数据未提供型号，暂不发送开锁指令';
    }
    if (status === CAP_TYPE_ID_INVALID) {
      return '门锁型号格式无法识别，暂不发送开锁指令';
    }
    if (status === CAP_TYPE_NOT_IN_CATALOG) {
      return '类型表未返回此型号，暂不发送开锁指令';
    }
    if (status === CAP_AES_FIELD_MISSING) {
      return '此型号未提供 aesSupport 字段，暂不发送开锁指令';
    }
    if (status === CAP_AES_FIELD_INVALID) {
      return '此型号的 aesSupport 字段值无法识别，暂不发送开锁指令';
    }
    if (status === CAP_CATALOG_CONFLICT) {
      return '类型表中此型号的能力记录冲突，暂不发送开锁指令';
    }
    if (status === CAP_RESOLVED) {
      return '门锁协议能力已确认';
    }
    return '门锁协议能力未知，暂不发送开锁指令';
  }
}
