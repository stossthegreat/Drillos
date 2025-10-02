// src/jobs/scheduler.ts
import { Queue, Worker } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { alarmsService } from "../services/alarms.service";
import { notificationsService } from "../services/notifications.service";
import { aiService } from "../services/ai.service";
import { voiceService } from "../services/voice.service";

export const schedulerQueue = new Queue("scheduler", { connection: redis });

export async function bootstrapSchedulers() {
  // scan for due alarms every minute
  await schedulerQueue.add(
    "scan-alarms",
    {},
    { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure daily briefs for each user (hourly)
  await schedulerQueue.add(
    "ensure-daily-briefs",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure random nudges per user (hourly)
  await schedulerQueue.add(
    "ensure-random-nudges",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );
}

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

// === tasks ===

async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({ where: { enabled: true, nextRun: { lte: now } } });

  for (const alarm of due) {
    try {
      await alarmsService.markFired(alarm.id, alarm.userId);

      // mentor gating by plan
      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      const isPro = user?.plan === "PRO";

      // Generate text only if PRO and briefs nudges allowed
      if (isPro) {
        const mentor = (user as any)?.mentorId || "marcus";
        const text = await aiService.generateMentorReply(
          alarm.userId,
          mentor as any,
          `Alarm fired: ${alarm.label}`,
          { purpose: "alarm", maxChars: 220, temperature: 0.4 }
        );

        let audioUrl: string | null = null;
        try {
          audioUrl = await voiceService.ttsToUrl(alarm.userId, text, mentor as any);
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

        const title = alarm.label;
        const body = text.length > 180 ? text.slice(0, 177) + "…" : text;
        await notificationsService.send(alarm.userId, title, body);
      } else {
        // non-PRO: still log; send simple notification without AI
        await prisma.event.create({
          data: {
            userId: alarm.userId,
            type: "alarm_fired_basic",
            payload: { alarmId: alarm.id, label: alarm.label },
          },
        });
        await notificationsService.send(alarm.userId, alarm.label, "Alarm time.");
      }
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

async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, briefsEnabled: true, plan: true },
  });
  for (const u of users) {
    if (!(u.briefsEnabled && u.plan === "PRO")) {
      // remove existing brief job if they are not PRO or disabled
      await schedulerQueue.removeRepeatableByKey(`scheduler:daily-brief:${u.id}`);
      continue;
    }
    const tz = u.tz || "Europe/London";
    await schedulerQueue.add(
      "daily-brief",
      { userId: u.id },
      {
        repeat: { pattern: "0 7 * * *", tz }, // 07:00
        jobId: `daily-brief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
  return { ok: true, users: users.length };
}

async function ensureRandomNudgeJobs() {
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, nudgesEnabled: true, plan: true },
  });

  for (const u of users) {
    const keyPrefix = `nudge:${u.id}:`;
    // clear previous configured nudges
    // NOTE: BullMQ doesn't expose list keys directly; relying on jobId uniqueness
    for (let i = 0; i < 4; i++) {
      try {
        await schedulerQueue.removeRepeatableByKey(`scheduler:${keyPrefix}${i}`);
      } catch {}
    }

    if (!(u.nudgesEnabled && u.plan === "PRO")) {
      continue; // disabled or not PRO => no random nudges
    }

    const tz = u.tz || "UTC";
    const count = 2 + Math.floor(Math.random() * 2); // 2–3 daily slots
    for (let i = 0; i < count; i++) {
      const hour = 10 + Math.floor(Math.random() * 9); // 10..18
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

async function runDailyBrief(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;

  if (!(user.plan === "PRO" && user.briefsEnabled)) {
    return { ok: false, skipped: true, reason: "briefs disabled or not PRO" };
  }

  const mentor = (user as any)?.mentorId || "marcus";
  const text = await aiService.generateMorningBrief(userId, mentor as any);

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor as any);
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

async function runRandomNudge(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;

  if (!(user.plan === "PRO" && user.nudgesEnabled)) {
    return { ok: false, skipped: true, reason: "nudges disabled or not PRO" };
  }

  const mentor = (user as any)?.mentorId || "marcus";
  const reason = "mid-day accountability";
  const text = await aiService.generateNudge(userId, mentor as any, reason);

  let audioUrl: string | null = null;
  try {
    audioUrl = await voiceService.ttsToUrl(userId, text, mentor as any);
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
