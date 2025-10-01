// src/jobs/scheduler.ts
import { Queue } from 'bullmq';
import { redis } from '../utils/redis';

const habitLoopQueue = new Queue('habit-loop', { connection: redis });

export async function scheduleDailyChecks(userId: string, mentor: string) {
  await habitLoopQueue.add(
    'daily-check',
    { userId, mentor },
    {
      repeat: { cron: '0 7 * * *' }, // every day at 7 AM
      removeOnComplete: true,
      removeOnFail: true,
    }
  );
}

export async function scheduleEveningDebriefs(userId: string, mentor: string) {
  await habitLoopQueue.add(
    'evening-debrief',
    { userId, mentor },
    {
      repeat: { cron: '0 21 * * *' }, // every day at 9 PM
      removeOnComplete: true,
      removeOnFail: true,
    }
  );
}

export async function scheduleHealthCheck() {
  await habitLoopQueue.add(
    'health-check',
    {},
    {
      repeat: { cron: '0 */6 * * *' }, // every 6 hours
      removeOnComplete: true,
      removeOnFail: true,
    }
  );
}
