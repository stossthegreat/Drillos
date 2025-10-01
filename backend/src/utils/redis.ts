import Redis from 'ioredis';

class RedisClient {
  private client: Redis;

  constructor() {
    this.client = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
      enableReadyCheck: false,
      maxRetriesPerRequest: null,
      lazyConnect: true,
    });

    this.client.on('error', (error) => {
      console.error('Redis connection error:', error);
    });

    this.client.on('connect', () => {
      console.log('Redis connected successfully');
    });
  }

  async get(key: string): Promise<string | null> {
    return await this.client.get(key);
  }

  async set(key: string, value: string, ttl?: number): Promise<'OK'> {
    if (ttl) {
      return await this.client.setex(key, ttl, value);
    }
    return await this.client.set(key, value);
  }

  async del(key: string): Promise<number> {
    return await this.client.del(key);
  }

  async exists(key: string): Promise<number> {
    return await this.client.exists(key);
  }

  async expire(key: string, seconds: number): Promise<number> {
    return await this.client.expire(key, seconds);
  }

  async hget(hash: string, field: string): Promise<string | null> {
    return await this.client.hget(hash, field);
  }

  async hset(hash: string, field: string, value: string): Promise<number> {
    return await this.client.hset(hash, field, value);
  }

  async hgetall(hash: string): Promise<Record<string, string>> {
    return await this.client.hgetall(hash);
  }

  async hdel(hash: string, field: string): Promise<number> {
    return await this.client.hdel(hash, field);
  }

  async quit(): Promise<void> {
    await this.client.quit();
  }

  getClient(): Redis {
    return this.client;
  }
}

export const redisClient = new RedisClient();
export default redisClient;
