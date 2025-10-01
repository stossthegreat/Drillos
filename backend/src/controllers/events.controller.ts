import { FastifyInstance } from 'fastify';
import { EventsService } from '../services/events.service';

export async function eventsController(fastify: FastifyInstance) {
  const eventsService = new EventsService();

  fastify.post('/v1/events', {
    schema: {
      tags: ['Events'],
      summary: 'Log a new user event',
      body: { type: 'object' },
      response: { 201: { type: 'object' } }
    }
  }, async (request: any, reply) => {
    const userId = request.user?.id || 'demo-user';
    const event = await eventsService.logEvent(userId, request.body.type, request.body.payload || {});
    reply.code(201);
    return event;
  });

  fastify.get('/v1/events/recent', {
    schema: {
      tags: ['Events'],
      summary: 'Get recent events',
      response: { 200: { type: 'array' } }
    }
  }, async (request: any) => {
    const userId = request.user?.id || 'demo-user';
    return eventsService.getRecentEvents(userId, 20);
  });

  fastify.get('/v1/events/patterns', {
    schema: {
      tags: ['Events'],
      summary: 'Analyze user event patterns',
      response: { 200: { type: 'object' } }
    }
  }, async (request: any) => {
    const userId = request.user?.id || 'demo-user';
    return eventsService.getPatterns(userId);
  });
}
