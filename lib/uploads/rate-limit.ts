const WINDOW_MS = 10 * 60 * 1000;
const MAX_UPLOAD_INTENTS = 20;
const MAX_TRACKED_USERS = 10_000;
const attempts = new Map<string, number[]>();

export function allowUploadIntent(userId: string, now = Date.now()) {
  const cutoff = now - WINDOW_MS;
  if (attempts.size >= MAX_TRACKED_USERS && !attempts.has(userId)) {
    attempts.forEach((timestamps, trackedUserId) => {
      const recent = timestamps.filter((timestamp: number) => timestamp > cutoff);
      if (recent.length === 0) attempts.delete(trackedUserId);
      else attempts.set(trackedUserId, recent);
    });
    if (attempts.size >= MAX_TRACKED_USERS) return false;
  }
  const recent = (attempts.get(userId) || []).filter((timestamp) => timestamp > cutoff);
  if (recent.length >= MAX_UPLOAD_INTENTS) {
    attempts.set(userId, recent);
    return false;
  }
  recent.push(now);
  attempts.set(userId, recent);
  return true;
}

export function resetUploadIntentRateLimitForTests() {
  attempts.clear();
}

export { MAX_UPLOAD_INTENTS, WINDOW_MS };
