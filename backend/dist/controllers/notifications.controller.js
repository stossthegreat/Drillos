"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificationsController = notificationsController;
const notifications_service_1 = require("../services/notifications.service");
async function notificationsController(fastify) {
    // Send notification immediately
    fastify.post("/api/v1/notifications/send", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { title, body } = req.body;
            return await notifications_service_1.notificationsService.send(userId, title, body);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // Schedule delayed notification
    fastify.post("/api/v1/notifications/schedule", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { title, body, delaySeconds } = req.body;
            return await notifications_service_1.notificationsService.schedule(userId, title, body, delaySeconds);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
