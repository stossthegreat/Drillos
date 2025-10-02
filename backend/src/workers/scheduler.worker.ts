// src/workers/scheduler.worker.ts
import { Queue, Worker, JobsOptions } from 'bullmq';
import { redis } from '../utils/redis';
import { prisma } from '../utils/db';
import { alarmsService } from '../services/alarms.service';
import { notificationsService } from '../services/notifications.service';
import { aiService } from '../services/ai.service';
import { voiceService } from '../services/voice.service';
import { nudgesService } from '../services/nudges.service';

const QUEUE_NAME = 'scheduler';
export const schedulerQueue = new Queue(QUEUE_NAME, { connection: redis });

/**
 * Environment toggles / limits
 */
const PRO_FEATURES_ENABLED = (process.env.PRO_FEATURES_ENABLED || 'true').toLowerCase() === 'true';
const FREE_NOTIFICATIONS_ENABLED = (process.env.FREE_NOTIFICATIONS_ENABLED || 'false').toLowerCase() === 'true';
const LLM_ENABLED = (process.env.LLM_ENABLED || 'true').toLowerCase() === 'true';
const TTS_ENABLED = (process.env.TTS_ENABLED || 'true').toLowerCase() === 'true';

const LLM_DAILY_MSG_CAP_FREE = Number(process.env.LLM_DAILY_MSG_CAP_FREE || 0);
const LLM_DAILY_MSG_CAP_PRO  = Number(process.env.LLM_DAILY_MSG_CAP_PRO  || 150);
const TTS_DAILY_CHAR_CAP_FREE = Number(process.env.TTS_DAILY_CHAR_CAP_FREE || 0);
const TTS_DAILY_CHAR_CAP_PRO  = Number(process.env.TTS_DAILY_CHAR_CAP_PRO  || 15000);

/**
 * Bootstrap repeatable jobs once at boot.
 * - scan-alarms: every minute
 * - ensure-daily-briefs: hourly (sets cron per user 07:00 local)
 * - auto-nudges: hourly
 * - ensure-evening-debriefs: hourly (sets cron per user 21:00 local)
 */
export async function bootstrapSchedulers() {
  const base: JobsOptions = { removeOnComplete: true, removeOnFail: true };
  await schedulerQueue.add('scan-alarms', {}, { repeat: { every: 60_000 }, ...base });
  await schedulerQueue.add('ensure-daily-briefs', {}, { repeat: { every: 60 * 60_000 }, ...base });
  await schedulerQueue.add('auto-nudges-hourly', {}, { repeat: { every: 60 * 60_000 }, ...base });
  await schedulerQueue.add('ensure-evening-debriefs', {}, { repeat: { every: 60 * 60_000 }, ...base });
}

/**
 * Worker
 */
new Worker(
  QUEUE_NAME,
  async (job) => {
    switch (job.name) {
      case 'scan-alarms':
        return scanDueAlarms();
      case 'ensure-daily-briefs':
        return ensureDailyBriefJobs();
      case 'daily-brief':
        return runDailyBrief(job.data.userId);
      case 'auto-nudges-hourly':
        return autoNudgesHourly();
      case 'ensure-evening-debriefs':
        return ensureEveningDebriefJobs();
      case 'evening-debrief':
        return runEveningDebrief(job.data.userId);
      default:
        return;
    }
  },
  { connection: redis }
);

/* =========================
   Helpers: gating / limits
   ========================= */

/** Redis key helpers */
function llmKey(userId: string) {
  const d = new Date().toISOString().slice(0, 10);
  return `llm:count:${userId}:${d}`;
}
function ttsKey(userId: string) {
  const d = new Date().toISOString().slice(0, 10);
  return `tts:chars:${userId}:${d}`;
}

/** plan -> caps & checks */
function capsFor(plan: 'FREE' | 'PRO') {
  return {
    llmCap: plan === 'PRO' ? LLM_DAILY_MSG_CAP_PRO : LLM_DAILY_MSG_CAP_FREE,
    ttsCap: plan === 'PRO' ? TTS_DAILY_CHAR_CAP_PRO : TTS_DAILY_CHAR_CAP_FREE,
  };
}

async function canUseLLM(userId: string, plan: 'FREE' | 'PRO') {
  if (!LLM_ENABLED) return false;
  if (plan === 'FREE' && PRO_FEATURES_ENABLED) return false; // AI behind paywall
  const cap = capsFor(plan).llmCap;
  if (cap <= 0) return false;
  const used = Number((await redis.get(llmKey(userId))) || 0);
  return used < cap;
}

async function incLLM(userId: string) {
  const key = llmKey(userId);
  const d = new Date();
  const ttl = secondsUntilMidnight(d);
  await redis.multi().incr(key).expire(key, ttl).exec();
}

async function canUseTTS(userId: string, plan: 'FREE' | 'PRO', chars: number) {
  if (!TTS_ENABLED) return false;
  if (plan === 'FREE' && PRO_FEATURES_ENABLED) return false;
  const cap = capsFor(plan).ttsCap;
  if (cap <= 0) return false;
  const used = Number((await redis.get(ttsKey(userId))) || 0);
  return used + chars <= cap;
}

async function incTTS(userId: string, chars: number) {
  const key = ttsKey(userId);
  const d = new Date();
  const ttl = secondsUntilMidnight(d);
  await redis
    .multi()
    .incrby(key, chars)
    .expire(key, ttl)
    .exec();
}

function secondsUntilMidnight(now = new Date()) {
  const end = new Date(now);
  end.setUTCHours(23, 59, 59, 999);
  return Math.max(1, Math.ceil((end.getTime() - now.getTime()) / 1000));
}

/* =========================
   scan-alarms (every minute)
   ========================= */
async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({
    where: { enabled: true, nextRun: { lte: now } },
  });

  let processed = 0;

  for (const alarm of due) {
    try {
      await alarmsService.markFired(alarm.id, alarm.userId);

      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      if (!user) continue;

      const plan = (user.plan as 'FREE' | 'PRO') || 'FREE';
      const mentor = (user as any).mentorId || 'marcus';

      // AI line (if allowed)
      let text = `${alarm.label}`;
      if (await canUseLLM(user.id, plan)) {
        text = await aiService.generateMentorReply(
          user.id,
          mentor,
          `Alarm fired: ${alarm.label}. Give a single compact order.`,
          { purpose: 'alarm', temperature: 0.4, maxChars: 220 }
        );
        await incLLM(user.id);
      }

      // Optional voice (if allowed)
      let audioUrl: string | null = null;
      if (text && (await canUseTTS(user.id, plan, text.length))) {
        try {
          audioUrl = await voiceService.ttsToUrl(user.id, text, mentor);
          await incTTS(user.id, text.length);
        } catch {
          audioUrl = null;
        }
      }

      await prisma.event.create({
        data: {
          userId: alarm.userId,
          type: 'alarm_fired_os',
          payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
        },
      });

      const body = text.length > 180 ? text.slice(0, 177) + '…' : text;
      if (plan === 'PRO' || FREE_NOTIFICATIONS_ENABLED) {
        await notificationsService.send(alarm.userId, alarm.label, body);
      }

      processed++;
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

  return { ok: true, processed };
}

/* =========================================
   ensure-daily-briefs (hourly) + daily-brief
   ========================================= */
async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || 'Europe/London';
    await schedulerQueue.add(
      'daily-brief',
      { userId: u.id },
      {
        repeat: { pattern: '0 7 * * *', tz }, // 07:00 local time
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
  if (!user) return { ok: false, reason: 'no-user' };

  const plan = (user.plan as 'FREE' | 'PRO') || 'FREE';
  const mentor = (user as any)?.mentorId || 'marcus';

  // Only generate AI brief if allowed
  let text = 'Good morning.';
  if (await canUseLLM(user.id, plan)) {
    text = await aiService.generateMorningBrief(userId, mentor);
    await incLLM(user.id);
  }

  let audioUrl: string | null = null;
  if (text && (await canUseTTS(user.id, plan, text.length))) {
    try {
      audioUrl = await voiceService.ttsToUrl(userId, text, mentor);
      await incTTS(user.id, text.length);
    } catch {
      audioUrl = null;
    }
  }

  await prisma.event.create({
    data: {
      userId,
      type: 'morning_brief',
      payload: { text, audioUrl },
    },
  });

  if (plan === 'PRO' || FREE_NOTIFICATIONS_ENABLED) {
    await notificationsService.send(
      userId,
      'Morning Brief',
      text.length > 180 ? text.slice(0, 177) + '…' : text
    );
  }

  return { ok: true };
}

/* ============================
   auto-nudges (hourly, all users)
   ============================ */
async function autoNudgesHourly() {
  const users = await prisma.user.findMany({
    select: { id: true, plan: true, tz: true, updatedAt: true },
  });

  let sent = 0;

  for (const u of users) {
    try {
      const plan = (u.plan as 'FREE' | 'PRO') || 'FREE';
      if (!(await canUseLLM(u.id, plan))) {
        continue;
      }

      const userRow = await prisma.user.findUnique({ where: { id: u.id } });
      const mentor = (userRow as any)?.mentorId || 'marcus';

      // Generate 1–2 nudges
      const nudges = await nudgesService.generateNudges(u.id);
      await incLLM(u.id);

      if (!nudges.length) continue;

      // Pick the strongest (first) for push (keep both in event log already created by service)
      const top = nudges[0];
      const body = top.message.length > 180 ? top.message.slice(0, 177) + '…' : top.message;

      if ((plan === 'PRO' || FREE_NOTIFICATIONS_ENABLED) && body) {
        await notificationsService.send(u.id, 'Nudge', body);
      }

      // optional: voice already generated inside nudgesService.speak(); nothing to do here
      sent++;
    } catch (e) {
      await prisma.event.create({
        data: { userId: u.id, type: 'nudge_error', payload: { message: (e as Error).message } },
      });
    }
  }

  return { ok: true, pushed: sent, users: users.length };
}

/* ==============================================
   ensure-evening-debriefs (hourly) + evening-debrief
   ============================================== */
async function ensureEveningDebriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || 'Europe/London';
    await schedulerQueue.add(
      'evening-debrief',
      { userId: u.id },
      {
        repeat: { pattern: '0 21 * * *', tz }, // 21:00 local time
        jobId: `evening-debrief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
  return { ok: true, users: users.length };
}

async function runEveningDebrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { ok: false, reason: 'no-user' };

  const plan = (user.plan as 'FREE' | 'PRO') || 'FREE';
  const mentor = (user as any)?.mentorId || 'marcus';

  // Update memory + generate debrief if allowed
  let text = 'Evening debrief.';
  if (await canUseLLM(user.id, plan)) {
    text = await aiService.generateEveningDebrief(userId, mentor);
    await incLLM(user.id);
  }

  let audioUrl: string | null = null;
  if (text && (await canUseTTS(user.id, plan, text.length))) {
    try {
      audioUrl = await voiceService.ttsToUrl(userId, text, mentor);
      await incTTS(user.id, text.length);
    } catch {
      audioUrl = null;
    }
  }

  await prisma.event.create({
    data: {
      userId,
      type: 'evening_debrief',
      payload: { text, audioUrl },
    },
  });

  if (plan === 'PRO' || FREE_NOTIFICATIONS_ENABLED) {
    await notificationsService.send(
      userId,
      'Evening Debrief',
      text.length > 180 ? text.slice(0, 177) + '…' : text
    );
  }

  return { ok: true };
}
