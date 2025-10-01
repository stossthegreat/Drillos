import { Queue } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
});

export class NotificationsQueue {
  private readonly queue: Queue;

  constructor() {
    this.queue = new Queue('notifications', {
      connection,
      defaultJobOptions: {
        removeOnComplete: 1000,
        removeOnFail: 1000,
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      },
    });
  }

  async enqueuePush(payload: {
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    audioUrl?: string | null;
  }) {
    await this.queue.add('push', payload);
  }

  async close() {
    await this.queue.close();
  }
}

export default NotificationsQueue;
