import { FastifyInstance } from 'fastify';
import { StreaksService } from '../services/streaks.service';

export async function streaksController(fastify: FastifyInstance) {
  const streaksService = new StreaksService();

  fastify.get('/v1/streaks/achievements', {
    schema: {
      tags: ['Streaks'],
      summary: 'Get user achievements',
      response: { 200: { type: 'object' } }
    }
  }, async (request: any) => {
    const userId = request.user?.id || 'demo-user';
    return streaksService.getUserAchievements(userId);
  });

  fastify.get('/v1/streaks/summary', {
    schema: {
      tags: ['Streaks'],
      summary: 'Get streak summary',
      response: { 200: { type: 'object' } }
    }
  }, async (request: any) => {
    const userId = request.user?.id || 'demo-user';
    return streaksService.getStreakSummary(userId);
  });
}
