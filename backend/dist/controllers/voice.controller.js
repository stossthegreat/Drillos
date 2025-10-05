"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = voiceController;
const voice_service_1 = require("../services/voice.service");
async function voiceController(fastify, _opts) {
    // POST /api/v1/voice/speak
    fastify.post("/api/v1/voice/speak", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { text, mentor } = req.body;
            const result = await voice_service_1.voiceService.speak(userId, text, mentor);
            const url = result.url;
            return { url };
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // GET /api/v1/voice/cache
    fastify.get("/api/v1/voice/cache", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            // Return empty cache for now - this would need to be implemented in voiceService
            return [];
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // GET /v1/voice/preset/:presetId
    fastify.get("/v1/voice/preset/:presetId", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { presetId } = req.params;
            // Return a mock preset for now
            return { id: presetId, name: "Default Voice", voice: "balanced" };
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // POST /v1/voice/tts
    fastify.post("/v1/voice/tts", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { text, voice } = req.body;
            const result = await voice_service_1.voiceService.speak(userId, text, voice || "balanced");
            return { voice: { url: result.url } };
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
