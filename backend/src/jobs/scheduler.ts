// src/jobs/scheduler.ts
import { Queue, Worker } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { alarmsService } from "../services/alarms.service";
import { notificationsService } from "../services/notifications.service";
import { aiService } from "../services/ai.service";
import { voiceService } from "../services/voice.service";
import { nudgesService } from "../services/nudges.service";
import { briefService } from "../services/brief.service";

export const schedulerQueue = new Queue("scheduler", { connection: redis });

export async function bootstrapSchedulers() {
  console.log("⏰ Bootstrapping OS schedulers...");

  await schedulerQueue.add(
    "scan-alarms",
    {},
    { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  await schedulerQueue.add(
    "ensure-daily-briefs",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  await schedulerQueue.add(
    "ensure-evening-debriefs",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  await schedulerQueue.add(
    "auto-nudges-hourly",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  console.log("✅ OS schedulers started (alarms, briefs, nudges, debriefs)");
}

new Worker(
  "scheduler",
  async (job) => {
    switch (job.name) {
      case "scan-alarms":
        return scanDueAlarms();
      case "ensure-daily-briefs":
        return ensureDailyBriefJobs();
      case "ensure-evening-debriefs":
        return ensureEveningDebriefJobs();
      case "auto-nudges-hourly":
        return autoNudgesHourly();
      case "daily-brief":
        return runDailyBrief(job.data.userId);
      case "evening-debrief":
        return runEveningDebrief(job.data.userId);
      default:
        return;
    }
  },
  { connection: redis }
);

// === TASKS ===

async function scanDueAlarms() {
  const now = new Date();
  const due = await prisma.alarm.findMany({ where: { enabled: true, nextRun: { lte: now } } });
  for (const alarm of due) {
    try {
      await alarmsService.markFired(alarm.id, alarm.userId);
      const user = await prisma.user.findUnique({ where: { id: alarm.userId } });
      if (!user) continue;

      const mentor = user.mentorId || "marcus";
      const text = await aiService.generateMentorReply(
        user.id,
        mentor,
        `Alarm fired: ${alarm.label}. Give one command.`
      );

      let audioUrl: string | null = null;
      try {
        audioUrl = await voiceService.ttsToUrl(user.id, text, mentor);
      } catch {}

      await prisma.event.create({
        data: {
          userId: user.id,
          type: "alarm_fired_os",
          payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
        },
      });

      await notificationsService.send(user.id, alarm.label, text);
    } catch (e) {
      console.error("Alarm error", e);
    }
  }
}

async function ensureDailyBriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    await schedulerQueue.add(
      "daily-brief",
      { userId: u.id },
      {
        repeat: { pattern: "0 7 * * *", tz: u.tz || "Europe/London" },
        jobId: `daily-brief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
}

async function ensureEveningDebriefJobs() {
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  for (const u of users) {
    await schedulerQueue.add(
      "evening-debrief",
      { userId: u.id },
      {
        repeat: { pattern: "0 21 * * *", tz: u.tz || "Europe/London" },
        jobId: `evening-debrief:${u.id}`,
        removeOnComplete: true,
        removeOnFail: true,
      }
    );
  }
}

async function autoNudgesHourly() {
  const users = await prisma.user.findMany({ select: { id: true, plan: true } });
  for (const u of users) {
    try {
      const nudges = await nudgesService.generateNudges(u.id);
      if (nudges.length) {
        await notificationsService.send(u.id, "Nudge", nudges[0].message);
      }
    } catch (e) {
      console.error("nudge err", e);
    }
  }
}

async function runDailyBrief(userId: string) {
  await briefService.getTodaysBrief(userId);
}

async function runEveningDebrief(userId: string) {
  await briefService.getEveningDebrief(userId);
}
