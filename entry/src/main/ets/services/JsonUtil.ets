/**
 * Small, defensive JSON helpers for the Yunmei API. The server wraps payloads in
 * `data`, `o`, `result` or single-element arrays, so lookups walk those containers
 * without trusting their shape or depth.
 */

export type JsonRecord = Record<string, Object>;

export function parseJson(text: string): Object | null {
  try {
    const value: Object = JSON.parse(text) as Object;
    return value;
  } catch (error) {
    return null;
  }
}

export function asRecord(value: Object | null | undefined): JsonRecord | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (Array.isArray(value)) {
    return null;
  }
  if (typeof value === 'object') {
    return value as JsonRecord;
  }
  return null;
}

export function asArray(value: Object | null | undefined): Object[] | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (Array.isArray(value)) {
    return value as Object[];
  }
  return null;
}

export function getField(record: JsonRecord | null, key: string): Object | null {
  if (record === null) {
    return null;
  }
  const value: Object | undefined = (record as Record<string, Object>)[key] as Object | undefined;
  if (value === undefined || value === null) {
    return null;
  }
  return value;
}

export function scalarText(value: Object | null): string {
  if (value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    return value.toString();
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  return '';
}

/** Trimmed text, used for identifiers and labels. */
export function textField(record: JsonRecord | null, key: string): string {
  return scalarText(getField(record, key)).trim();
}

/** Exact text, used for `lockSecret` so its bytes are never silently changed. */
export function exactField(record: JsonRecord | null, key: string): string {
  return scalarText(getField(record, key));
}

export function firstText(record: JsonRecord | null, first: string, second: string): string {
  const one = textField(record, first);
  return one.length > 0 ? one : textField(record, second);
}

export function hasField(record: JsonRecord | null, key: string): boolean {
  if (record === null) {
    return false;
  }
  return Object.keys(record).indexOf(key) >= 0;
}

export function flagOf(value: Object | null): boolean | null {
  if (value === null) {
    return null;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    if (value === 1) {
      return true;
    }
    if (value === 0) {
      return false;
    }
    return null;
  }
  if (typeof value === 'string') {
    const text = value.trim();
    if (text === 'true' || text === '1') {
      return true;
    }
    if (text === 'false' || text === '0') {
      return false;
    }
  }
  return null;
}

/** Returns the first object (depth-limited) that owns `field`. */
export function objectWithField(value: Object | null, field: string, depth: number): JsonRecord | null {
  if (value === null || depth > 6) {
    return null;
  }
  const record = asRecord(value);
  if (record !== null) {
    if (hasField(record, field)) {
      return record;
    }
    const keys: string[] = ['o', 'data', 'result'];
    for (let i = 0; i < keys.length; i++) {
      const child = objectWithField(getField(record, keys[i]), field, depth + 1);
      if (child !== null) {
        return child;
      }
    }
    return null;
  }
  const array = asArray(value);
  if (array !== null && array.length === 1) {
    return objectWithField(array[0], field, depth + 1);
  }
  return null;
}

/** Finds the first array payload inside `data`, `list`, `result` or `o`. */
export function arrayPayload(value: Object | null, depth: number): Object[] | null {
  if (value === null || depth > 6) {
    return null;
  }
  const direct = asArray(value);
  if (direct !== null) {
    return direct;
  }
  const record = asRecord(value);
  if (record === null) {
    return null;
  }
  const keys: string[] = ['data', 'list', 'result', 'o'];
  for (let i = 0; i < keys.length; i++) {
    const child = getField(record, keys[i]);
    const found = arrayPayload(child, depth + 1);
    if (found !== null) {
      return found;
    }
  }
  return null;
}

/**
 * Returns a non-empty message when the payload explicitly reports failure.
 * `success` must be boolean-ish; unknown success values are treated as errors.
 */
export function failureMessage(value: Object | null, depth: number): string {
  if (value === null || depth > 6) {
    return '';
  }
  const record = asRecord(value);
  if (record === null) {
    const array = asArray(value);
    if (array !== null && array.length === 1) {
      return failureMessage(array[0], depth + 1);
    }
    return '';
  }
  const successRaw = getField(record, 'success');
  const success = flagOf(successRaw);
  if (successRaw !== null && success === null) {
    return '服务器成功标记格式异常，已停止处理。';
  }
  const errorRaw = getField(record, 'error');
  let failed = success === false;
  if (errorRaw !== null && errorRaw !== undefined) {
    const errorFlag = flagOf(errorRaw);
    if (errorFlag !== false) {
      failed = true;
    }
  }
  if (failed) {
    const message = firstText(record, 'msg', 'message');
    return message.length > 0 ? message : '服务器拒绝本次请求。';
  }
  const keys: string[] = ['data', 'o', 'result', 'list'];
  for (let i = 0; i < keys.length; i++) {
    const child = getField(record, keys[i]);
    if (child !== null) {
      const nested = failureMessage(child, depth + 1);
      if (nested.length > 0) {
        return nested;
      }
    }
  }
  return '';
}

export function positiveSuccess(value: Object | null, depth: number): boolean {
  if (value === null || depth > 6) {
    return false;
  }
  const record = asRecord(value);
  if (record !== null) {
    if (flagOf(getField(record, 'success')) === true) {
      return true;
    }
    const keys: string[] = ['data', 'o', 'result'];
    for (let i = 0; i < keys.length; i++) {
      if (positiveSuccess(getField(record, keys[i]), depth + 1)) {
        return true;
      }
    }
    return false;
  }
  const array = asArray(value);
  if (array !== null && array.length === 1) {
    return positiveSuccess(array[0], depth + 1);
  }
  return false;
}
