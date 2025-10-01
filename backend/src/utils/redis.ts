// src/utils/redis.ts
import IORedis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

let redis: IORedis;

declare global {
  // eslint-disable-next-line no-var
  var __redis__: IORedis | undefined;
}

if (process.env.NODE_ENV !== 'production') {
  if (!global.__redis__) {
    global.__redis__ = new IORedis(REDIS_URL, {
      lazyConnect: false,
      maxRetriesPerRequest: 2,
    });
  }
  redis = global.__redis__;
} else {
  redis = new IORedis(REDIS_URL, {
    lazyConnect: false,
    maxRetriesPerRequest: 2,
  });
}

redis.on('error', (err) => {
  console.error('🔴 Redis error:', err?.message || err);
});

export { redis };
