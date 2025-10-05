"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nudgesController = nudgesController;
const nudges_service_1 = require("../services/nudges.service");
async function nudgesController(fastify) {
    const nudgesService = new nudges_service_1.NudgesService();
    fastify.get("/api/v1/nudges", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            return await nudgesService.generateNudges(userId);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
