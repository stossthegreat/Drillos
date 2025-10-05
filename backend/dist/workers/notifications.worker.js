"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const bullmq_1 = require("bullmq");
const redis_1 = require("../utils/redis");
const notifications_service_1 = require("../services/notifications.service");
new bullmq_1.Worker("notification", async (job) => {
    const { userId, title, body } = job.data;
    console.log(`📣 Worker sending notification -> ${userId}: ${title}`);
    await notifications_service_1.notificationsService.send(userId, title, body);
}, { connection: redis_1.redis });
