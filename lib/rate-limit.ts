import { LRUCache } from "lru-cache";

type Entry = {
  count: number;
  resetAt: number;
};

const globalForRateLimit = globalThis as unknown as {
  limiter?: LRUCache<string, Entry>;
};

const limiter =
  globalForRateLimit.limiter ??
  new LRUCache<string, Entry>({
    max: 10000,
    ttl: 1000 * 60 * 10,
  });

if (process.env.NODE_ENV !== "production") {
  globalForRateLimit.limiter = limiter;
}

export function checkRateLimit(key: string, limit = 20, windowMs = 60_000) {
  const now = Date.now();
  const existing = limiter.get(key);

  if (!existing || existing.resetAt <= now) {
    limiter.set(key, { count: 1, resetAt: now + windowMs }, { ttl: windowMs });
    return { allowed: true, remaining: limit - 1, resetAt: now + windowMs };
  }

  if (existing.count >= limit) {
    return { allowed: false, remaining: 0, resetAt: existing.resetAt };
  }

  existing.count += 1;
  limiter.set(key, existing, { ttl: existing.resetAt - now });

  return {
    allowed: true,
    remaining: Math.max(0, limit - existing.count),
    resetAt: existing.resetAt,
  };
}
