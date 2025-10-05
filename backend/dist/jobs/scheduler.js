"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.schedulerQueue = void 0;
exports.bootstrapSchedulers = bootstrapSchedulers;
const bullmq_1 = require("bullmq");
const redis_1 = require("../utils/redis");
exports.schedulerQueue = new bullmq_1.Queue("scheduler", { connection: redis_1.redis });
/**
 * Boot the repeatable background jobs for DrillOS
 * NOTE: Worker is instantiated in src/workers/scheduler.worker.ts
 */
async function bootstrapSchedulers() {
    console.log("🔧 Bootstrapping scheduler jobs...");
    // scan alarms every minute
    await exports.schedulerQueue.add("scan-alarms", {}, { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true });
    // re-ensure daily briefs hourly
    await exports.schedulerQueue.add("ensure-daily-briefs", {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
    // re-ensure random nudges hourly
    await exports.schedulerQueue.add("ensure-random-nudges", {}, { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true });
    console.log("✅ Scheduler jobs registered");
}
