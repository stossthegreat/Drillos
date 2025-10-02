import { FastifyInstance } from "fastify";
import { voiceService } from "../services/voice.service";

export async function voiceController(fastify: FastifyInstance) {
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
}
