import { Queue, Worker } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { alarmsService } from "../services/alarms.service";
import { notificationsService } from "../services/notifications.service";
import { aiService } from "../services/ai.service";
import { voiceService } from "../services/voice.service";

export const schedulerQueue = new Queue("scheduler", { connection: redis });

type MentorId = "marcus" | "drill" | "buddha" | "lincoln" | "confucius";

/**
 * Boot the repeatable background jobs for DrillOS
 */
export async function bootstrapSchedulers() {
  // scan alarms every minute
  await schedulerQueue.add(
    "scan-alarms",
    {},
    { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure daily briefs hourly
  await schedulerQueue.add(
    "ensure-daily-briefs",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure random nudges hourly
  await schedulerQueue.add(
    "ensure-random-nudges",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );
}

/**
 * Main worker
 */
new Worker(
  "scheduler",
  async (job) => {
    switch (job.name) {
      case "scan-alarms":
        return scanDueAlarms();
      case "ensure-daily-briefs":
        return ensureDailyBriefJobs();
      case "ensure-random-nudges":
        return ensureRandomNudgeJobs();
      case "daily-brief":
        return runDailyBrief(job.data.userId);
      case "random-nudge":
        return runRandomNudge(job.data.userId);
      default:
        return;
    }
  },
  { connection: redis }
);

/* ======================
   1️⃣ Scan Due Alarms
   ====================== */
async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({
    where: { enabled: true, nextRun: { lte: now } },
  });

  for (const alarm of due) {
    try {
      await alarmsService.markFired(alarm.id, alarm.userId);

      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      if (!user) continue;

      const isPro = user.plan === "PRO";
      const mentor = ((user as any)?.mentorId || "marcus") as MentorId;

      let text = `${alarm.label}`;
      if (isPro) {
        text = await aiService.generateMentorReply(
          alarm.userId,
          mentor,
          `Alarm fired: ${alarm.label}`,
          { purpose: "alarm", maxChars: 220, temperature: 0.4 }
        );
      }

      let audioUrl: string | null = null;
      try {
        audioUrl = await voiceService.ttsToUrl(alarm.userId, text, mentor);
      } catch {
        audioUrl = null;
      }

      await prisma.event.create({
        data: {
          userId: alarm.userId,
          type: "alarm_fired_os",
          payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
        },
      });

      const body = text.length > 180 ? text.slice(0, 177) + "…" : text;
      await notificationsService.send(alarm.userId, alarm.label, body);
    } catch (e) {
      await prisma.event.create({
        data: {
          userId: alarm.userId,
          type: "alarm_error",
          payload: { alarmId: alarm.id, message: (e as Error).message },
        },
      });
    }
  }

  return { ok: true, processed: due.length };
}

/* ============================
   2️⃣ Daily Briefs (07:00)
   ============================ */
async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, briefsEnabled: true, plan: true },
  });

  for (const u of users) {
    if (!(u.briefsEnabled && u.plan === "PRO")) continue;

    const tz = u.tz || "Europe/London";
    await schedulerQueue.add(
      "daily-brief",
      { userId: u.id },
      {
        repeat: { pattern: "0 7 * * *", tz },
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
  if (!user || !(user.plan === "PRO" && user.briefsEnabled)) return;

  const mentor = ((user as any)?.mentorId || "marcus") as MentorId;
  const text = await aiService.generateMorningBrief(userId, mentor);

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor);
  } catch {
    audioUrl = null;
  }

  await prisma.event.create({
    data: { userId, type: "morning_brief", payload: { text, audioUrl } },
  });

  await notificationsService.send(
    userId,
    "Morning Brief",
    text.length > 180 ? text.slice(0, 177) + "…" : text
  );

  return { ok: true };
}

/* ============================
   3️⃣ Random Nudges (10–18h)
   ============================ */
async function ensureRandomNudgeJobs() {
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, nudgesEnabled: true, plan: true },
  });

  for (const u of users) {
    if (!(u.nudgesEnabled && u.plan === "PRO")) continue;

    const tz = u.tz || "UTC";
    const count = 2 + Math.floor(Math.random() * 2); // 2–3 per day

    for (let i = 0; i < count; i++) {
      const hour = 10 + Math.floor(Math.random() * 9); // 10–18
      const minute = Math.floor(Math.random() * 60);
      const cron = `${minute} ${hour} * * *`;

      await schedulerQueue.add(
        "random-nudge",
        { userId: u.id },
        {
          repeat: { pattern: cron, tz },
          jobId: `nudge:${u.id}:${i}`,
          removeOnComplete: true,
          removeOnFail: true,
        }
      );
    }
  }
  return { ok: true };
}

async function runRandomNudge(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || !(user.plan === "PRO" && user.nudgesEnabled)) return;

  const mentor = ((user as any)?.mentorId || "marcus") as MentorId;
  const reason = "mid-day accountability";
  const text = await aiService.generateNudge(userId, mentor, reason);

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor);
  } catch {
    audioUrl = null;
  }

  await prisma.event.create({
    data: { userId, type: "mentor_nudge", payload: { text, audioUrl } },
  });

  await notificationsService.send(
    userId,
    "Nudge",
    text.length > 180 ? text.slice(0, 177) + "…" : text
  );

  return { ok: true };
}
