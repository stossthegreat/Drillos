"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.memoryController = memoryController;
const memory_service_1 = require("../services/memory.service");
async function memoryController(fastify) {
    // GET /api/v1/memory
    fastify.get("/api/v1/memory", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            return await memory_service_1.memoryService.getFacts(userId);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // POST /api/v1/memory
    fastify.post("/api/v1/memory", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { key, value } = req.body;
            return await memory_service_1.memoryService.updateFact(userId, key, value);
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
//# sourceMappingURL=memory.controller.js.map