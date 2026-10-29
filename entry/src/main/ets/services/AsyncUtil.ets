export function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void) => void) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

/** Races a task against a timer; the losing task is left to settle harmlessly. */
export function withTimeout<T>(task: Promise<T>, ms: number, message: string): Promise<T> {
  return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void) => {
    let finished = false;
    const timer = setTimeout(() => {
      if (!finished) {
        finished = true;
        reject(new Error(message));
      }
    }, ms);
    task.then((value: T) => {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        resolve(value);
      }
    }).catch((error: Error) => {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        reject(error);
      }
    });
  });
}

export function errorText(error: Error): string {
  const text = error.message;
  return text !== undefined && text.length > 0 ? text : '操作失败，请稍后重试';
}
