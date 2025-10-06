// ✅ Worker for OS brain tasks ONLY (no habit timing here).
import { Queue, Worker } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { aiService } from "../services/ai.service";
import { notificationsService } from "../services/notifications.service";
import { voiceService } from "../services/voice.service";
import { nudgesService } from "../services/nudges.service";

const QUEUE = "scheduler";
export const schedulerQueue = new Queue(QUEUE, { connection: redis });

const PRO_FEATURES_ENABLED = (process.env.PRO_FEATURES_ENABLED || "true").toLowerCase() === "true";
const FREE_NOTIFICATIONS_ENABLED = (process.env.FREE_NOTIFICATIONS_ENABLED || "false").toLowerCase() === "true";

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
  return { ok: true, users: users.length };
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
  return { ok: true, users: users.length };
}

async function runDailyBrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { ok: false, reason: "no-user" };

  const mentor = (user as any)?.mentorId || "marcus";
  const text = await aiService.generateMorningBrief(userId, mentor as any).catch(() => "Good morning.");
  let audioUrl: string | null = null;
  try { audioUrl = await voiceService.ttsToUrl(userId, text, mentor as any); } catch { audioUrl = null; }

  await prisma.event.create({
    data: { userId, type: "morning_brief", payload: { text, audioUrl } }
  });

  if (user.plan === "PRO" || FREE_NOTIFICATIONS_ENABLED) {
    await notificationsService.send(userId, "Morning Brief", text.length > 180 ? text.slice(0,177)+"…" : text);
  }
  return { ok: true };
}

async function runEveningDebrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { ok: false, reason: "no-user" };

  const mentor = (user as any)?.mentorId || "marcus";
  const text = await aiService.generateEveningDebrief(userId, mentor as any).catch(() => "Evening debrief.");
  let audioUrl: string | null = null;
  try { audioUrl = await voiceService.ttsToUrl(userId, text, mentor as any); } catch { audioUrl = null; }

  await prisma.event.create({
    data: { userId, type: "evening_debrief", payload: { text, audioUrl } }
  });

  if (user.plan === "PRO" || FREE_NOTIFICATIONS_ENABLED) {
    await notificationsService.send(userId, "Evening Debrief", text.length > 180 ? text.slice(0,177)+"…" : text);
  }
  return { ok: true };
}

async function autoNudgesHourly() {
  const users = await prisma.user.findMany({ select: { id: true, plan: true } });
  let pushed = 0;
  for (const u of users) {
    try {
      if (u.plan !== "PRO" && !FREE_NOTIFICATIONS_ENABLED) continue;
      const nudges = await nudgesService.generateNudges(u.id);
      if (!nudges || (Array.isArray(nudges) && nudges.length === 0)) continue;
      const top = Array.isArray(nudges) ? nudges[0] : (nudges as any).nudges?.[0];
      if (!top?.message) continue;
      await notificationsService.send(u.id, "Nudge", top.message.length > 180 ? top.message.slice(0,177)+"…" : top.message);
      pushed++;
    } catch (e) {
      await prisma.event.create({
        data: { userId: u.id, type: "nudge_error", payload: { message: (e as Error).message } }
      });
    }
  }
  return { ok: true, pushed };
}

new Worker(QUEUE, async (job) => {
  switch (job.name) {
    case "ensure-daily-briefs": return ensureDailyBriefJobs();
    case "daily-brief":         return runDailyBrief(job.data.userId);
    case "ensure-evening-debriefs": return ensureEveningDebriefJobs();
    case "evening-debrief":     return runEveningDebrief(job.data.userId);
    case "auto-nudges-hourly":  return autoNudgesHourly();
    default: return;
  }
}, { connection: redis });

console.log("🧠 Scheduler Worker Started (OS brain only)");
