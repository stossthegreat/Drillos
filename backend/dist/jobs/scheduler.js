"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.schedulerQueue = void 0;
exports.bootstrapSchedulers = bootstrapSchedulers;
const bullmq_1 = require("bullmq");
const redis_1 = require("../utils/redis");
const db_1 = require("../utils/db");
const alarms_service_1 = require("../services/alarms.service");
const notifications_service_1 = require("../services/notifications.service");
const ai_service_1 = require("../services/ai.service");
const voice_service_1 = require("../services/voice.service");
exports.schedulerQueue = new bullmq_1.Queue("scheduler", { connection: redis_1.redis });
/**
 * Boot the repeatable background jobs for DrillOS
 */
async function bootstrapSchedulers() {
    // scan alarms every minute
    await exports.schedulerQueue.add("scan-alarms", {}, { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true });
    // re-ensure daily briefs hourly
    await exports.schedulerQueue.add("ensure-daily-briefs", {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
    // re-ensure random nudges hourly
    await exports.schedulerQueue.add("ensure-random-nudges", {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
}
/**
 * Main worker
 */
new bullmq_1.Worker("scheduler", async (job) => {
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
}, { connection: redis_1.redis });
/* ======================
   1️⃣ Scan Due Alarms
   ====================== */
async function scanDueAlarms() {
    const now = new Date();
    const due = await db_1.prisma.alarm.findMany({
        where: { enabled: true, nextRun: { lte: now } },
    });
    for (const alarm of due) {
        try {
            await alarms_service_1.alarmsService.markFired(alarm.id, alarm.userId);
            const user = await db_1.prisma.user.findUnique({ where: { id: alarm.userId } });
            if (!user)
                continue;
            const isPro = user.plan === "PRO";
            const mentor = (user?.mentorId || "marcus");
            let text = `${alarm.label}`;
            if (isPro) {
                text = await ai_service_1.aiService.generateMentorReply(alarm.userId, mentor, `Alarm fired: ${alarm.label}`, { purpose: "alarm", maxChars: 220, temperature: 0.4 });
            }
            let audioUrl = null;
            try {
                audioUrl = await voice_service_1.voiceService.ttsToUrl(alarm.userId, text, mentor);
            }
            catch {
                audioUrl = null;
            }
            await db_1.prisma.event.create({
                data: {
                    userId: alarm.userId,
                    type: "alarm_fired_os",
                    payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
                },
            });
            const body = text.length > 180 ? text.slice(0, 177) + "…" : text;
            await notifications_service_1.notificationsService.send(alarm.userId, alarm.label, body);
        }
        catch (e) {
            await db_1.prisma.event.create({
                data: {
                    userId: alarm.userId,
                    type: "alarm_error",
                    payload: { alarmId: alarm.id, message: e.message },
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
    const users = await db_1.prisma.user.findMany({
        select: { id: true, tz: true, briefsEnabled: true, plan: true },
    });
    for (const u of users) {
        if (!(u.briefsEnabled && u.plan === "PRO"))
            continue;
        const tz = u.tz || "Europe/London";
        await exports.schedulerQueue.add("daily-brief", { userId: u.id }, {
            repeat: { pattern: "0 7 * * *", tz },
            jobId: `daily-brief:${u.id}`,
            removeOnComplete: true,
            removeOnFail: true,
        });
    }
    return { ok: true, users: users.length };
}
async function runDailyBrief(userId) {
    const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !(user.plan === "PRO" && user.briefsEnabled))
        return;
    const mentor = (user?.mentorId || "marcus");
    const text = await ai_service_1.aiService.generateMorningBrief(userId, mentor);
    let audioUrl = null;
    try {
        audioUrl = await voice_service_1.voiceService.ttsToUrl(userId, text, mentor);
    }
    catch {
        audioUrl = null;
    }
    await db_1.prisma.event.create({
        data: { userId, type: "morning_brief", payload: { text, audioUrl } },
    });
    await notifications_service_1.notificationsService.send(userId, "Morning Brief", text.length > 180 ? text.slice(0, 177) + "…" : text);
    return { ok: true };
}
/* ============================
   3️⃣ Random Nudges (10–18h)
   ============================ */
async function ensureRandomNudgeJobs() {
    const users = await db_1.prisma.user.findMany({
        select: { id: true, tz: true, nudgesEnabled: true, plan: true },
    });
    for (const u of users) {
        if (!(u.nudgesEnabled && u.plan === "PRO"))
            continue;
        const tz = u.tz || "UTC";
        const count = 2 + Math.floor(Math.random() * 2); // 2–3 per day
        for (let i = 0; i < count; i++) {
            const hour = 10 + Math.floor(Math.random() * 9); // 10–18
            const minute = Math.floor(Math.random() * 60);
            const cron = `${minute} ${hour} * * *`;
            await exports.schedulerQueue.add("random-nudge", { userId: u.id }, {
                repeat: { pattern: cron, tz },
                jobId: `nudge:${u.id}:${i}`,
                removeOnComplete: true,
                removeOnFail: true,
            });
        }
    }
    return { ok: true };
}
async function runRandomNudge(userId) {
    const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !(user.plan === "PRO" && user.nudgesEnabled))
        return;
    const mentor = (user?.mentorId || "marcus");
    const reason = "mid-day accountability";
    const text = await ai_service_1.aiService.generateNudge(userId, mentor, reason);
    let audioUrl = null;
    try {
        audioUrl = await voice_service_1.voiceService.ttsToUrl(userId, text, mentor);
    }
    catch {
        audioUrl = null;
    }
    await db_1.prisma.event.create({
        data: { userId, type: "mentor_nudge", payload: { text, audioUrl } },
    });
    await notifications_service_1.notificationsService.send(userId, "Nudge", text.length > 180 ? text.slice(0, 177) + "…" : text);
    return { ok: true };
}
