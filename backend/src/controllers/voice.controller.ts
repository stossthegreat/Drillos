import { FastifyInstance, FastifyPluginOptions } from "fastify";
import { voiceService } from "../services/voice.service";

export default async function voiceController(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // POST /api/v1/voice/speak
  fastify.post("/api/v1/voice/speak", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { text, mentor } = req.body as { text: string; mentor: string };
      const url = await voiceService.generateVoice(userId, mentor, text);

      return { url };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // GET /api/v1/voice/cache
  fastify.get("/api/v1/voice/cache", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      return await voiceService.listCache(userId);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // GET /v1/voice/preset/:presetId
  fastify.get("/v1/voice/preset/:presetId", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { presetId } = req.params;
      // Return a mock preset for now
      return { id: presetId, name: "Default Voice", voice: "balanced" };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // POST /v1/voice/tts
  fastify.post("/v1/voice/tts", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { text, voice } = req.body;
      const result = await voiceService.speak(userId, text, voice || "balanced");
      
      return { voice: { url: result.url } };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
