// src/utils/queues.ts
import { Queue } from 'bullmq';
import type { QueueOptions, JobsOptions } from 'bullmq';
import { getRedis } from './redis';

export const QUEUE_NAMES = {
  EMAIL: 'email',
  NOTIFICATION: 'notification',
  ANALYTICS: 'analytics',
  VOICE: 'voice',
  HABIT_LOOP: 'habit-loop',
} as const;

// Alias for backward compatibility
export const JOB_TYPES = QUEUE_NAMES;

const connection = getRedis();

const defaultOpts = (removeOnComplete = 100, removeOnFail = 50): QueueOptions & { defaultJobOptions: JobsOptions } => ({
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete,
    removeOnFail,
  },
});

export const emailQueue = new Queue(QUEUE_NAMES.EMAIL, defaultOpts(100, 50));
export const notificationQueue = new Queue(QUEUE_NAMES.NOTIFICATION, defaultOpts(100, 50));
export const analyticsQueue = new Queue(QUEUE_NAMES.ANALYTICS, {
  ...defaultOpts(50, 25),
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 5000 },
    removeOnComplete: 50,
    removeOnFail: 25,
  },
});
export const voiceQueue = new Queue(QUEUE_NAMES.VOICE, defaultOpts(20, 10));
export const habitLoopQueue = new Queue(QUEUE_NAMES.HABIT_LOOP, defaultOpts(200, 50));

export async function checkQueueHealth(): Promise<Record<string, boolean>> {
  const result: Record<string, boolean> = {};
  const entries = [
    ['email', emailQueue],
    ['notification', notificationQueue],
    ['analytics', analyticsQueue],
    ['voice', voiceQueue],
    ['habit-loop', habitLoopQueue],
  ] as const;

  await Promise.all(
    entries.map(async ([name, q]) => {
      try {
        await q.getWaiting(); // ping
        result[name] = true;
      } catch {
        result[name] = false;
      }
    }),
  );

  return result;
}

export async function closeAllQueues(): Promise<void> {
  await Promise.all([emailQueue.close(), notificationQueue.close(), analyticsQueue.close(), voiceQueue.close(), habitLoopQueue.close()]);
}
