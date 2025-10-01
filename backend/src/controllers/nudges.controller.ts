import { FastifyInstance } from "fastify";
import { NudgesService } from "../services/nudges.service";

export async function nudgesController(fastify: FastifyInstance) {
  const nudgesService = new NudgesService();

  fastify.get("/api/v1/nudges", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      return await nudgesService.generateNudges(userId);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
