// src/jobs/scheduler.ts
import { Queue, Worker } from 'bullmq';
import { redis } from '../utils/redis';
import { prisma } from '../utils/db';
import { alarmsService } from '../services/alarms.service';
import { notificationsService } from '../services/notifications.service';
import { aiService } from '../services/ai.service';
import { voiceService } from '../services/voice.service';

export const schedulerQueue = new Queue('scheduler', { connection: redis });

// Bootstrap repeatable jobs
export async function bootstrapSchedulers() {
  await schedulerQueue.add('scan-alarms', {}, { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true });
  await schedulerQueue.add('ensure-daily-briefs', {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
  await schedulerQueue.add('ensure-evening-debriefs', {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
  await schedulerQueue.add('ensure-random-nudges', {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }); // hourly re-seed
}

// Worker
new Worker(
  'scheduler',
  async (job) => {
    switch (job.name) {
      case 'scan-alarms': return scanDueAlarms();
      case 'ensure-daily-briefs': return ensureDailyBriefJobs();
      case 'ensure-evening-debriefs': return ensureEveningDebriefJobs();
      case 'ensure-random-nudges': return ensureRandomNudgeJobs();
      case 'daily-brief': return runDailyBrief(job.data.userId);
      case 'evening-debrief': return runEveningDebrief(job.data.userId);
      case 'random-nudge': return runRandomNudge(job.data.userId);
      default: return;
    }
  },
  { connection: redis }
);

// === Random Nudges ===
async function ensureRandomNudgeJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || 'UTC';
    const nudgeCount = 2 + Math.floor(Math.random() * 2); // 2–3 nudges
    for (let i = 0; i < nudgeCount; i++) {
      const hour = 10 + Math.floor(Math.random() * 9); // between 10–19
      const minute = Math.floor(Math.random() * 60);
      const cron = `${minute} ${hour} * * *`;
      await schedulerQueue.add(
        'random-nudge',
        { userId: u.id },
        { repeat: { pattern: cron, tz }, jobId: `nudge:${u.id}:${i}`, removeOnComplete: true, removeOnFail: true }
      );
    }
  }
  return { ok: true, users: users.length };
}

async function runRandomNudge(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;

  const mentor = (user as any)?.mentorId || 'marcus';
  const text = await aiService.generateNudge(userId, mentor, 'midday motivation');

  let audioUrl: string | null = null;
  try { audioUrl = await voiceService.ttsToUrl(userId, text, mentor); } catch { audioUrl = null; }

  await prisma.event.create({ data: { userId, type: 'random_nudge', payload: { text, audioUrl } } });
  await notificationsService.send(userId, 'Nudge', text);
  return { ok: true };
}
