import { FastifyInstance } from "fastify";
import { StreaksService } from "../services/streaks.service";

export async function streaksController(fastify: FastifyInstance) {
  const streaksService = new StreaksService();

  // ✅ Get streak summary
  fastify.get("/api/v1/streaks/summary", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      return await streaksService.getStreakSummary(userId);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ✅ Get user achievements
  fastify.get("/api/v1/streaks/achievements", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      return await streaksService.getUserAchievements(userId);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
