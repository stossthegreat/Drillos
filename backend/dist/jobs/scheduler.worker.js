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
exports.schedulerQueue = new bullmq_1.Queue('scheduler', { connection: redis_1.redis });
// Repeatable jobs set up once at boot
async function bootstrapSchedulers() {
    // Runs every minute to scan due alarms
    await exports.schedulerQueue.add('scan-alarms', {}, { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true });
    // Ensure daily briefs are scheduled per user TZ (re-upsert hourly)
    await exports.schedulerQueue.add('ensure-daily-briefs', {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
}
// Worker
new bullmq_1.Worker('scheduler', async (job) => {
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
}, { connection: redis_1.redis });
// === tasks ===
async function scanDueAlarms() {
    const now = new Date();
    const due = await db_1.prisma.alarm.findMany({
        where: { enabled: true, nextRun: { lte: now } },
    });
    for (const alarm of due) {
        try {
            // Log + schedule next run
            await alarms_service_1.alarmsService.markFired(alarm.id, alarm.userId);
            // Generate mentor alarm line (AI, no mock)
            const user = await db_1.prisma.user.findUnique({ where: { id: alarm.userId } });
            const mentor = user?.mentorId || 'marcus';
            const text = await ai_service_1.aiService.generateMentorReply(alarm.userId, mentor, `Alarm fired: ${alarm.label}`);
            // (Optional) voice URL for the alarm
            let audioUrl = null;
            try {
                audioUrl = await voice_service_1.voiceService.ttsToUrl(alarm.userId, text, mentor);
            }
            catch (e) {
                // voice failure shouldn’t block alarm
                audioUrl = null;
            }
            // Log OS event
            await db_1.prisma.event.create({
                data: {
                    userId: alarm.userId,
                    type: 'alarm_fired_os',
                    payload: { alarmId: alarm.id, label: alarm.label, text, audioUrl },
                },
            });
            // Push notification
            const title = alarm.label;
            const body = text.length > 180 ? text.slice(0, 177) + '…' : text;
            await notifications_service_1.notificationsService.send(alarm.userId, title, body);
        }
        catch (e) {
            await db_1.prisma.event.create({
                data: {
                    userId: alarm.userId,
                    type: 'alarm_error',
                    payload: { alarmId: alarm.id, message: e.message },
                },
            });
        }
    }
    return { ok: true, processed: due.length };
}
async function ensureDailyBriefJobs() {
    const users = await db_1.prisma.user.findMany({ select: { id: true, tz: true } });
    for (const u of users) {
        const tz = u.tz || 'Europe/London';
        // Create/refresh a repeatable job per user at 07:00 local time
        await exports.schedulerQueue.add('daily-brief', { userId: u.id }, {
            repeat: { pattern: '0 7 * * *', tz }, // cron 07:00 daily
            jobId: `daily-brief:${u.id}`,
            removeOnComplete: true,
            removeOnFail: true,
        });
    }
    return { ok: true, users: users.length };
}
async function runDailyBrief(userId) {
    const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
    if (!user)
        return;
    // Pull today’s context
    const habits = await db_1.prisma.habit.findMany({ where: { userId } });
    const recent = await db_1.prisma.event.findMany({
        where: { userId },
        orderBy: { ts: 'desc' },
        take: 50,
    });
    // AI mentor brief (no mock)
    const mentor = user?.mentorId || 'marcus';
    const prompt = `Morning brief. User has ${habits.length} habits. Patterns from last 48h: ${recent
        .map((e) => e.type)
        .slice(0, 10)
        .join(', ')}. Give 2–3 crisp orders for the day.`;
    const text = await ai_service_1.aiService.generateMentorReply(userId, mentor, prompt);
    // Optional voice
    let audioUrl = null;
    try {
        audioUrl = await voice_service_1.voiceService.ttsToUrl(userId, text, mentor);
    }
    catch {
        audioUrl = null;
    }
    await db_1.prisma.event.create({
        data: {
            userId,
            type: 'morning_brief',
            payload: { text, audioUrl },
        },
    });
    await notifications_service_1.notificationsService.send(userId, 'Morning Brief', text.length > 180 ? text.slice(0, 177) + '…' : text);
    return { ok: true };
}
