import { Queue, Worker, JobsOptions } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { alarmsService } from "../services/alarms.service";
import { notificationsService } from "../services/notifications.service";
import { aiService } from "../services/ai.service";
import { voiceService } from "../services/voice.service";
import { nudgesService } from "../services/nudges.service";

const QUEUE_NAME = "scheduler";
export const schedulerQueue = new Queue(QUEUE_NAME, { connection: redis });

/**
 * === Environment toggles ===
 */
const PRO_FEATURES_ENABLED = (process.env.PRO_FEATURES_ENABLED || "true").toLowerCase() === "true";
const FREE_NOTIFICATIONS_ENABLED = (process.env.FREE_NOTIFICATIONS_ENABLED || "false").toLowerCase() === "true";
const LLM_ENABLED = (process.env.LLM_ENABLED || "true").toLowerCase() === "true";
const TTS_ENABLED = (process.env.TTS_ENABLED || "true").toLowerCase() === "true";

const LLM_DAILY_MSG_CAP_FREE = Number(process.env.LLM_DAILY_MSG_CAP_FREE || 0);
const LLM_DAILY_MSG_CAP_PRO = Number(process.env.LLM_DAILY_MSG_CAP_PRO || 150);
const TTS_DAILY_CHAR_CAP_FREE = Number(process.env.TTS_DAILY_CHAR_CAP_FREE || 0);
const TTS_DAILY_CHAR_CAP_PRO = Number(process.env.TTS_DAILY_CHAR_CAP_PRO || 15000);

/**
 * === Bootstrap jobs ===
 */
export async function bootstrapSchedulers() {
  const base: JobsOptions = { removeOnComplete: true, removeOnFail: true };
  await schedulerQueue.add("scan-alarms", {}, { repeat: { every: 60_000 }, ...base });
  await schedulerQueue.add("ensure-daily-briefs", {}, { repeat: { every: 60 * 60_000 }, ...base });
  await schedulerQueue.add("auto-nudges-hourly", {}, { repeat: { every: 60 * 60_000 }, ...base });
  await schedulerQueue.add("ensure-evening-debriefs", {}, { repeat: { every: 60 * 60_000 }, ...base });
}

/**
 * === Worker ===
 */
new Worker(
  QUEUE_NAME,
  async (job) => {
    switch (job.name) {
      case "scan-alarms":
        return scanDueAlarms();
      case "ensure-daily-briefs":
        return ensureDailyBriefJobs();
      case "daily-brief":
        return runDailyBrief(job.data.userId);
      case "auto-nudges-hourly":
        return autoNudgesHourly();
      case "ensure-random-nudges":
        return autoNudgesHourly(); // Same as auto-nudges-hourly
      case "ensure-evening-debriefs":
        return ensureEveningDebriefJobs();
      case "evening-debrief":
        return runEveningDebrief(job.data.userId);
      default:
        return;
    }
  },
  { connection: redis }
);

console.log("🔧 Scheduler worker initialized and listening for jobs...");

/* =========================
   Alarm Handling
   ========================= */
async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({ where: { enabled: true, nextRun: { lte: now } } });
  let processed = 0;

  for (const alarm of due) {
    try {
      await alarmsService.markFired(alarm.id, alarm.userId);

      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      if (!user) continue;

      const plan = (user.plan as "FREE" | "PRO") || "FREE";
      const mentor = (user as any)?.mentorId || "marcus";

      let text = `${alarm.label}`;
      if (await canUseLLM(user.id, plan)) {
        text = await aiService.generateMentorReply(user.id, mentor, `Alarm fired: ${alarm.label}`);
        await incLLM(user.id);
      }

      let audioUrl: string | null = null;
      if (text && (await canUseTTS(user.id, plan, text.length))) {
        audioUrl = await voiceService.ttsToUrl(user.id, text, mentor).catch(() => null);
        await incTTS(user.id, text.length);
      }

      await prisma.event.create({
        data: { userId: alarm.userId, type: "alarm_fired_os", payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl } },
      });

      if (plan === "PRO" || FREE_NOTIFICATIONS_ENABLED) {
        await notificationsService.send(alarm.userId, alarm.label, text.slice(0, 180));
      }

      processed++;
    } catch (e: any) {
      await prisma.event.create({
        data: { userId: alarm.userId, type: "alarm_error", payload: { alarmId: alarm.id, message: e.message } },
      });
    }
  }

  return { ok: true, processed };
}

/* =========================
   Briefs, Nudges, Debriefs
   ========================= */
async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || "Europe/London";
    await schedulerQueue.add("daily-brief", { userId: u.id }, {
      repeat: { pattern: "0 7 * * *", tz },
      jobId: `daily-brief:${u.id}`,
      removeOnComplete: true,
      removeOnFail: true
    });
  }
  return { ok: true };
}

async function runDailyBrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { ok: false, reason: "no-user" };

  const plan = (user.plan as "FREE" | "PRO") || "FREE";
  const mentor = (user as any)?.mentorId || "marcus";

  let text = "Good morning.";
  if (await canUseLLM(user.id, plan)) {
    text = await aiService.generateMorningBrief(userId, mentor);
    await incLLM(user.id);
  }

  let audioUrl: string | null = null;
  if (await canUseTTS(user.id, plan, text.length)) {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor).catch(() => null);
    await incTTS(user.id, text.length);
  }

  await prisma.event.create({ data: { userId, type: "morning_brief", payload: { text, audioUrl } } });
  await notificationsService.send(userId, "Morning Brief", text.slice(0, 180));
  return { ok: true };
}

async function autoNudgesHourly() {
  const users = await prisma.user.findMany({ select: { id: true, plan: true } });
  for (const u of users) {
    const plan = (u.plan as "FREE" | "PRO") || "FREE";
    if (!(await canUseLLM(u.id, plan))) continue;

    const mentor = (await prisma.user.findUnique({ where: { id: u.id } }))?.mentorId || "marcus";
    const result = await nudgesService.generateNudges(u.id);
    await incLLM(u.id);

    if (!result.success || !result.nudges || result.nudges.length === 0) continue;
    const nudge = result.nudges[0];
    await notificationsService.send(u.id, "Nudge", nudge.message.slice(0, 180));
  }
  return { ok: true };
}

async function ensureEveningDebriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    const tz = u.tz || "Europe/London";
    await schedulerQueue.add("evening-debrief", { userId: u.id }, {
      repeat: { pattern: "0 21 * * *", tz },
      jobId: `evening-debrief:${u.id}`,
      removeOnComplete: true,
      removeOnFail: true
    });
  }
  return { ok: true };
}

async function runEveningDebrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { ok: false, reason: "no-user" };

  const plan = (user.plan as "FREE" | "PRO") || "FREE";
  const mentor = (user as any)?.mentorId || "marcus";

  let text = "Evening debrief.";
  if (await canUseLLM(user.id, plan)) {
    text = await aiService.generateEveningDebrief(userId, mentor);
    await incLLM(user.id);
  }

  let audioUrl: string | null = null;
  if (await canUseTTS(user.id, plan, text.length)) {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor).catch(() => null);
    await incTTS(user.id, text.length);
  }

  await prisma.event.create({ data: { userId, type: "evening_debrief", payload: { text, audioUrl } } });
  await notificationsService.send(userId, "Evening Debrief", text.slice(0, 180));
  return { ok: true };
}

/* =========================
   Helper Utilities
   ========================= */
function llmKey(userId: string) {
  const d = new Date().toISOString().split("T")[0];
  return `llm:count:${userId}:${d}`;
}
function ttsKey(userId: string) {
  const d = new Date().toISOString().split("T")[0];
  return `tts:chars:${userId}:${d}`;
}
function secondsUntilMidnight(now = new Date()) {
  const end = new Date(now);
  end.setUTCHours(23, 59, 59, 999);
  return Math.max(1, Math.ceil((end.getTime() - now.getTime()) / 1000));
}
async function incLLM(userId: string) {
  const ttl = secondsUntilMidnight();
  await redis.multi().incr(llmKey(userId)).expire(llmKey(userId), ttl).exec();
}
async function incTTS(userId: string, chars: number) {
  const ttl = secondsUntilMidnight();
  await redis.multi().incrby(ttsKey(userId), chars).expire(ttsKey(userId), ttl).exec();
}
async function canUseLLM(userId: string, plan: "FREE" | "PRO") {
  if (!LLM_ENABLED) return false;
  const cap = plan === "PRO" ? LLM_DAILY_MSG_CAP_PRO : LLM_DAILY_MSG_CAP_FREE;
  const used = Number((await redis.get(llmKey(userId))) || 0);
  return used < cap;
}
async function canUseTTS(userId: string, plan: "FREE" | "PRO", chars: number) {
  if (!TTS_ENABLED) return false;
  const cap = plan === "PRO" ? TTS_DAILY_CHAR_CAP_PRO : TTS_DAILY_CHAR_CAP_FREE;
  const used = Number((await redis.get(ttsKey(userId))) || 0);
  return used + chars <= cap;
}
