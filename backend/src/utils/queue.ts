import { Queue } from 'bullmq';
import { redisClient } from './redis';

// Queue names
export const QUEUE_NAMES = {
  EMAIL: 'email',
  NOTIFICATION: 'notification',
  ANALYTICS: 'analytics',
  VOICE: 'voice',
} as const;

// Job types
export const JOB_TYPES = {
  SEND_EMAIL: 'send-email',
  SEND_NOTIFICATION: 'send-notification',
  PROCESS_ANALYTICS: 'process-analytics',
  GENERATE_VOICE: 'generate-voice',
} as const;

// Queue instances
export const emailQueue = new Queue(QUEUE_NAMES.EMAIL, {
  connection: redisClient.getClient(),
  defaultJobOptions: {
    removeOnComplete: 100,
    removeOnFail: 50,
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
  },
});

export const notificationQueue = new Queue(QUEUE_NAMES.NOTIFICATION, {
  connection: redisClient.getClient(),
  defaultJobOptions: {
    removeOnComplete: 100,
    removeOnFail: 50,
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
  },
});

export const analyticsQueue = new Queue(QUEUE_NAMES.ANALYTICS, {
  connection: redisClient.getClient(),
  defaultJobOptions: {
    removeOnComplete: 50,
    removeOnFail: 25,
    attempts: 2,
    backoff: {
      type: 'fixed',
      delay: 5000,
    },
  },
});

export const voiceQueue = new Queue(QUEUE_NAMES.VOICE, {
  connection: redisClient.getClient(),
  defaultJobOptions: {
    removeOnComplete: 20,
    removeOnFail: 10,
    attempts: 2,
    backoff: {
      type: 'exponential',
      delay: 3000,
    },
  },
});

// Queue health check
export async function checkQueueHealth(): Promise<Record<string, boolean>> {
  const queues = [
    { name: 'email', queue: emailQueue },
    { name: 'notification', queue: notificationQueue },
    { name: 'analytics', queue: analyticsQueue },
    { name: 'voice', queue: voiceQueue },
  ];

  const health: Record<string, boolean> = {};

  for (const { name, queue } of queues) {
    try {
      await queue.getWaiting();
      health[name] = true;
    } catch (error) {
      console.error(`Queue ${name} health check failed:`, error);
      health[name] = false;
    }
  }

  return health;
}

// Close all queues
export async function closeAllQueues(): Promise<void> {
  await Promise.all([
    emailQueue.close(),
    notificationQueue.close(),
    analyticsQueue.close(),
    voiceQueue.close(),
  ]);
}

export default {
  emailQueue,
  notificationQueue,
  analyticsQueue,
  voiceQueue,
  checkQueueHealth,
  closeAllQueues,
};
