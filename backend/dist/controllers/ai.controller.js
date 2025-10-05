"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = aiController;
const ai_service_1 = require("../services/ai.service");
async function aiController(fastify, _opts) {
    // POST /api/v1/ai/reply
    fastify.post("/api/v1/ai/reply", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { message, mentor } = req.body;
            const response = await ai_service_1.aiService.generateMentorReply(userId, mentor, message);
            return { reply: response };
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
    // POST /v1/chat
    fastify.post("/v1/chat", async (req, reply) => {
        try {
            const userId = req.user?.id || req.headers["x-user-id"];
            if (!userId)
                return reply.code(401).send({ error: "Unauthorized" });
            const { message, mode, includeVoice } = req.body;
            const mentor = mode === 'strict' ? 'drill' : mode === 'light' ? 'buddha' : 'marcus';
            const response = await ai_service_1.aiService.generateMentorReply(userId, mentor, message);
            const result = { reply: response };
            // Add voice if requested
            if (includeVoice) {
                try {
                    const { voiceService } = await Promise.resolve().then(() => __importStar(require("../services/voice.service")));
                    const voiceResult = await voiceService.speak(userId, response, mentor);
                    result.voice = { url: voiceResult.url };
                }
                catch (voiceErr) {
                    console.warn('Voice generation failed:', voiceErr);
                }
            }
            return result;
        }
        catch (err) {
            return reply.code(500).send({ error: err.message });
        }
    });
}
