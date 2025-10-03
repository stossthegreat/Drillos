// src/utils/redis.ts
import IORedis, { Redis } from 'ioredis';
import { ENV, isDev } from './env';
import { logger } from './logger';

let client: Redis | null = null;

function makeClient(): Redis {
  const c = new IORedis(ENV.REDIS_URL, {
    lazyConnect: false,
    maxRetriesPerRequest: null, // Required for BullMQ blocking operations
    enableOfflineQueue: false,
  });

  c.on('connect', () => logger.info({ url: maskRedis(ENV.REDIS_URL) }, '🔌 Redis connected'));
  c.on('error', (err) => logger.error({ err }, '🔴 Redis error'));
  c.on('reconnecting', () => logger.warn('Redis reconnecting…'));
  c.on('end', () => logger.warn('Redis connection closed'));

  return c;
}

export function getRedis(): Redis {
  if (!client) {
    // reuse in dev hot-reload
    const g = global as any;
    if (isDev && g.__redis__) {
      client = g.__redis__ as Redis;
    } else {
      client = makeClient();
      if (isDev) (global as any).__redis__ = client;
    }
  }
  return client!;
}

export const redis = getRedis(); // Export as 'redis' for compatibility

export async function redisHealthCheck(): Promise<boolean> {
  try {
    const c = getRedis();
    const pong = await c.ping();
    return pong === 'PONG';
  } catch {
    return false;
  }
}

export async function closeRedis(): Promise<void> {
  if (client) {
    try {
      await client.quit();
    } catch {
      await client.disconnect();
    }
    client = null;
  }
}

function maskRedis(url: string) {
  try {
    const u = new URL(url);
    if (u.password) u.password = '***';
    return u.toString();
  } catch {
    return 'redis://***';
  }
}
