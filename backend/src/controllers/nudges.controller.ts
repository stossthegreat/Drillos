import { FastifyInstance } from 'fastify';
import { NudgesService } from '../services/nudges.service';

export async function nudgesController(fastify: FastifyInstance) {
  const nudgesService = new NudgesService();

  fastify.get('/v1/nudges', {
    schema: {
      tags: ['Nudges'],
      summary: 'Generate smart nudges for the user',
      response: { 200: { type: 'array' } }
    }
  }, async (request: any) => {
    const userId = request.user?.id || 'demo-user';
    return nudgesService.generateNudges(userId);
  });
}
