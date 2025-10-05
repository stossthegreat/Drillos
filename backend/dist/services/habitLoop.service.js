"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.habitLoopService = exports.HabitLoopService = void 0;
// src/services/habitLoop.service.ts
const bullmq_1 = require("bullmq");
const redis_1 = require("../utils/redis");
const db_1 = require("../utils/db");
const ai_service_1 = require("./ai.service");
const queue = new bullmq_1.Queue("habit-loop", { connection: redis_1.redis });
class HabitLoopService {
    async scheduleDailyCheck(userId, mentor) {
        const jobOpts = { removeOnComplete: true, removeOnFail: true };
        await queue.add("daily-check", { userId, mentor }, jobOpts);
    }
}
exports.HabitLoopService = HabitLoopService;
new bullmq_1.Worker("habit-loop", async (job) => {
    if (job.name === "daily-check") {
        const { userId, mentor } = job.data;
        // analyse habits & events
        const habits = await db_1.prisma.habit.findMany({ where: { userId } });
        const events = await db_1.prisma.event.findMany({
            where: { userId },
            orderBy: { ts: "desc" },
            take: 20,
        });
        // create a mentor message proactively
        const text = await ai_service_1.aiService.generateMentorReply(userId, mentor, "Daily proactive check-in");
        await db_1.prisma.event.create({
            data: {
                userId,
                type: "os_nudge",
                payload: { text, habitsCount: habits.length, recentEvents: events },
            },
        });
        // push notification later (NotificationService will pick it up)
    }
}, { connection: redis_1.redis });
exports.habitLoopService = new HabitLoopService();
//# sourceMappingURL=habitLoop.service.js.map