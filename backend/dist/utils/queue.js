"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.habitLoopQueue = exports.voiceQueue = exports.analyticsQueue = exports.notificationQueue = exports.emailQueue = exports.JOB_TYPES = exports.QUEUE_NAMES = void 0;
exports.checkQueueHealth = checkQueueHealth;
exports.closeAllQueues = closeAllQueues;
// src/utils/queues.ts
const bullmq_1 = require("bullmq");
const redis_1 = require("./redis");
exports.QUEUE_NAMES = {
    EMAIL: 'email',
    NOTIFICATION: 'notification',
    ANALYTICS: 'analytics',
    VOICE: 'voice',
    HABIT_LOOP: 'habit-loop',
};
// Alias for backward compatibility
exports.JOB_TYPES = exports.QUEUE_NAMES;
const connection = (0, redis_1.getRedis)();
const defaultOpts = (removeOnComplete = 100, removeOnFail = 50) => ({
    connection,
    defaultJobOptions: {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete,
        removeOnFail,
    },
});
exports.emailQueue = new bullmq_1.Queue(exports.QUEUE_NAMES.EMAIL, defaultOpts(100, 50));
exports.notificationQueue = new bullmq_1.Queue(exports.QUEUE_NAMES.NOTIFICATION, defaultOpts(100, 50));
exports.analyticsQueue = new bullmq_1.Queue(exports.QUEUE_NAMES.ANALYTICS, {
    ...defaultOpts(50, 25),
    defaultJobOptions: {
        attempts: 2,
        backoff: { type: 'fixed', delay: 5000 },
        removeOnComplete: 50,
        removeOnFail: 25,
    },
});
exports.voiceQueue = new bullmq_1.Queue(exports.QUEUE_NAMES.VOICE, defaultOpts(20, 10));
exports.habitLoopQueue = new bullmq_1.Queue(exports.QUEUE_NAMES.HABIT_LOOP, defaultOpts(200, 50));
async function checkQueueHealth() {
    const result = {};
    const entries = [
        ['email', exports.emailQueue],
        ['notification', exports.notificationQueue],
        ['analytics', exports.analyticsQueue],
        ['voice', exports.voiceQueue],
        ['habit-loop', exports.habitLoopQueue],
    ];
    await Promise.all(entries.map(async ([name, q]) => {
        try {
            await q.getWaiting(); // ping
            result[name] = true;
        }
        catch {
            result[name] = false;
        }
    }));
    return result;
}
async function closeAllQueues() {
    await Promise.all([exports.emailQueue.close(), exports.notificationQueue.close(), exports.analyticsQueue.close(), exports.voiceQueue.close(), exports.habitLoopQueue.close()]);
}
