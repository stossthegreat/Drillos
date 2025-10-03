// src/controllers/brief.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { briefService } from '../services/brief.service';

function getUserIdOrThrow(req: any): string {
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    throw new Error('Unauthorized: missing user id');
  }
  return uid;
}

export default async function briefRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // GET /v1/brief/today
  fastify.get('/v1/brief/today', {
    schema: { 
      tags: ['Brief'], 
      summary: 'Get today\'s morning brief',
      response: { 
        200: { type: 'object' }, 
        400: { type: 'object' } 
      } 
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      return await briefService.getTodaysBrief(userId);
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // GET /v1/brief/evening
  fastify.get('/v1/brief/evening', {
    schema: { 
      tags: ['Brief'], 
      summary: 'Get evening debrief',
      response: { 
        200: { type: 'object' }, 
        400: { type: 'object' } 
      } 
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      return await briefService.getEveningDebrief(userId);
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // POST /v1/brief/today/select
  fastify.post('/v1/brief/today/select', {
    schema: { 
      tags: ['Brief'], 
      summary: 'Select habit for today',
      body: {
        type: 'object',
        required: ['habitId'],
        properties: {
          habitId: { type: 'string' },
          date: { type: 'string' }
        }
      },
      response: { 
        200: { type: 'object' }, 
        400: { type: 'object' } 
      } 
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { habitId, date } = req.body as { habitId: string; date?: string };
      
      // For now, just return success - this would need to be implemented in briefService
      return { success: true, habitId, date };
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // POST /v1/brief/today/deselect
  fastify.post('/v1/brief/today/deselect', {
    schema: { 
      tags: ['Brief'], 
      summary: 'Deselect habit for today',
      body: {
        type: 'object',
        required: ['habitId'],
        properties: {
          habitId: { type: 'string' },
          date: { type: 'string' }
        }
      },
      response: { 
        200: { type: 'object' }, 
        400: { type: 'object' } 
      } 
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { habitId, date } = req.body as { habitId: string; date?: string };
      
      // For now, just return success - this would need to be implemented in briefService
      return { success: true, habitId, date };
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });
}
