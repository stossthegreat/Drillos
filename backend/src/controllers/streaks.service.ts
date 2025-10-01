import { FastifyInstance } from "fastify";
import { StreaksService } from "../services/streaks.service";

export async function streaksController(fastify: FastifyInstance) {
  const service = new StreaksService();

  // Overall + per-category streak summary for Streak Page
  fastify.get("/api/v1/streaks/summary", async (req, reply) => {
    const userId = (req as any).user?.id || "demo-user-123";
    const summary = await service.getStreakSummary(userId);
    return summary;
  });

  // Achievements (latest unlocked + pending)
  fastify.get("/api/v1/streaks/achievements", async (req, reply) => {
    const userId = (req as any).user?.id || "demo-user-123";
    const achievements = await service.getUserAchievements(userId);
    return achievements;
  });
}
