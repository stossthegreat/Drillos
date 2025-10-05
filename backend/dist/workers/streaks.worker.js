"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const bullmq_1 = require("bullmq");
const redis_1 = require("../utils/redis");
const streaks_service_1 = require("../services/streaks.service");
const notifications_service_1 = require("../services/notifications.service");
const streaksService = new streaks_service_1.StreaksService();
// 🏅 Worker that checks streaks and pushes mentor-style alerts
new bullmq_1.Worker("streaks", async (job) => {
    const { userId } = job.data;
    const summary = await streaksService.getStreakSummary(userId);
    const achievements = await streaksService.getUserAchievements(userId);
    if (achievements.achievements.length > 0) {
        const latest = achievements.achievements.slice(-1)[0];
        await notifications_service_1.notificationsService.send(userId, "🏅 Achievement Unlocked", `You just hit a ${latest.title}. Keep the fire alive!`);
    }
    if (summary.overall < 2) {
        await notifications_service_1.notificationsService.send(userId, "⚠️ Streak at Risk", "Your habits are cooling off. Get back in the fight today.");
    }
}, { connection: redis_1.redis });
