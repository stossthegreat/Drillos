import { FastifyInstance, FastifyPluginOptions } from "fastify";
import { aiService } from "../services/ai.service";

export default async function aiController(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // POST /api/v1/ai/reply
  fastify.post("/api/v1/ai/reply", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { message, mentor } = req.body as { message: string; mentor: string };

      const response = await aiService.generateMentorReply(userId, mentor as any, message);
      return { reply: response };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // POST /v1/chat
  fastify.post("/v1/chat", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { message, mode, includeVoice } = req.body as { 
        message: string; 
        mode: string; 
        includeVoice: boolean; 
      };

      const mentor = mode === 'strict' ? 'drill' : mode === 'light' ? 'buddha' : 'marcus';
      const response = await aiService.generateMentorReply(userId, mentor, message);
      
      const result: any = { reply: response };
      
      // Add voice if requested
      if (includeVoice) {
        try {
          const { voiceService } = await import("../services/voice.service");
          const voiceResult = await voiceService.speak(userId, response, mentor);
          result.voice = { url: voiceResult.url };
        } catch (voiceErr) {
          console.warn('Voice generation failed:', voiceErr);
        }
      }
      
      return result;
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
