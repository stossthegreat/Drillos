import { FastifyInstance } from "fastify";
import { memoryService } from "../services/memory.service";

export async function memoryController(fastify: FastifyInstance) {
  // GET /api/v1/memory
  fastify.get("/api/v1/memory", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      return await memoryService.getFacts(userId);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // POST /api/v1/memory
  fastify.post("/api/v1/memory", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { key, value } = req.body as { key: string; value: any };
      return await memoryService.updateFact(userId, key, value);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
