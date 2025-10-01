import { FastifyInstance } from "fastify";
import { aiService } from "../services/ai.service";

export async function aiController(fastify: FastifyInstance) {
  // POST /api/v1/ai/reply
  fastify.post("/api/v1/ai/reply", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { message, mentor } = req.body as { message: string; mentor: string };

      const response = await aiService.generateMentorReply(userId, mentor, message);
      return { reply: response };
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
