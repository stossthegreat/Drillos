import { Queue, Worker } from 'bullmq';
import { redis } from '../utils/redis';
import { prisma } from '../utils/db';
import { alarmsService } from '../services/alarms.service';
import { notificationsService } from '../services/notifications.service';
import { aiService } from '../services/ai.service';
import { voiceService } from '../services/voice.service';

export const schedulerQueue = new Queue('scheduler', { connection: redis });

// Repeatable jobs set up once at boot
export async function bootstrapSchedulers() {
  // Runs every minute to scan due alarms
  await schedulerQueue.add(
    'scan-alarms',
    {},
    { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // Ensure daily briefs are scheduled per user TZ (re-upsert hourly)
  await schedulerQueue.add(
    'ensure-daily-briefs',
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );
}

// Worker
new Worker(
  'scheduler',
  async (job) => {
    switch (job.name) {
      case 'scan-alarms':
        return scanDueAlarms();
      case 'ensure-daily-briefs':
        return ensureDailyBriefJobs();
      case 'daily-brief':
        return runDailyBrief(job.data.userId);
      default:
        return;
    }
  },
  { connection: redis }
);

// === tasks ===

async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({
    where: { enabled: true, nextRun: { lte: now } },
  });

  for (const alarm of due) {
    try {
      // Log + schedule next run
      await alarmsService.markFired(alarm.id, alarm.userId);

      // Generate mentor alarm line (AI, no mock)
      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      const mentor = (user as any)?.mentorId || 'marcus';
      const text = await aiService.generateMentorReply(
        alarm.userId,
        mentor,
        `Alarm fired: ${alarm.label}`
      );

      // (Optional) voice URL for the alarm
      let audioUrl: string | null = null;
      try {
        audioUrl = await voiceService.ttsToUrl(alarm.userId, text, mentor);
      } catch (e) {
        // voice failure shouldn’t block alarm
        audioUrl = null;
      }

      // Log OS event
      await prisma.event.create({
        data: {
          userId: alarm.userId,
          type: 'alarm_fired_os',
          payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
        },
      });

      // Push notification
      const title = alarm.label;
      const body = text.length > 180 ? text.slice(0, 177) + '…' : text;
      await notificationsService.send(alarm.userId, title, body);
    } catch (e) {
      await prisma.event.create({
        data: {
          userId: alarm.userId,
          type: 'alarm_error',
          payload: { alarmId: alarm.id, message: (e as Error).message },
        },
      });
    }
  }

  return { ok: true, processed: due.length };
}

async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || 'Europe/London';
    // Create/refresh a repeatable job per user at 07:00 local time
    await schedulerQueue.add(
      'daily-brief',
      { userId: u.id },
      {
        repeat: { pattern: '0 7 * * *', tz }, // cron 07:00 daily
        jobId: `daily-brief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
  return { ok: true, users: users.length };
}

async function runDailyBrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;

  // Pull today’s context
  const habits = await prisma.habit.findMany({ where: { userId } });
  const recent = await prisma.event.findMany({
    where: { userId },
    orderBy: { ts: 'desc' },
    take: 50,
  });

  // AI mentor brief (no mock)
  const mentor = (user as any)?.mentorId || 'marcus';
  const prompt = `Morning brief. User has ${habits.length} habits. Patterns from last 48h: ${recent
    .map((e) => e.type)
    .slice(0, 10)
    .join(', ')}. Give 2–3 crisp orders for the day.`;
  const text = await aiService.generateMentorReply(userId, mentor, prompt);

  // Optional voice
  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor);
  } catch {
    audioUrl = null;
  }

  await prisma.event.create({
    data: {
      userId,
      type: 'morning_brief',
      payload: { text, audioUrl },
    },
  });

  await notificationsService.send(
    userId,
    'Morning Brief',
    text.length > 180 ? text.slice(0, 177) + '…' : text
  );

  return { ok: true };
}
