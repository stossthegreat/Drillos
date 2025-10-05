"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.streaksController = streaksController;
const streaks_service_1 = require("../services/streaks.service");
async function streaksController(fastify) {
    const streaksService = new streaks_service_1.StreaksService();
    // ✅ Get streak summary
    fastify.get("/api/v1/streaks/summary", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            return await streaksService.getStreakSummary(userId);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // ✅ Get user achievements
    fastify.get("/api/v1/streaks/achievements", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            return await streaksService.getUserAchievements(userId);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
