// src/controllers/brief.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { briefService } from '../services/brief.service';
import { todayService } from '../services/today.service';

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
      summary: 'Select a habit or task for today',
      body: {
        type: 'object',
        properties: {
          habitId: { type: 'string' },
          taskId: { type: 'string' },
          date: { type: 'string' },
        },
      },
      response: { 200: { type: 'object' }, 400: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const body = req.body as { habitId?: string; taskId?: string; date?: string };
      if (!body.habitId && !body.taskId) {
        return reply.code(400).send({ error: 'habitId or taskId is required' });
      }
      const res = await todayService.selectForToday(userId, body.habitId, body.taskId, body.date);
      return res;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });

  // POST /v1/brief/today/deselect
  fastify.post('/v1/brief/today/deselect', {
    schema: {
      tags: ['Brief'],
      summary: 'Deselect (remove) a habit or task from today',
      body: {
        type: 'object',
        properties: {
          habitId: { type: 'string' },
          taskId: { type: 'string' },
          date: { type: 'string' },
        },
      },
      response: { 200: { type: 'object' }, 400: { type: 'object' } },
    },
  }, async (req: any, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const body = req.body as { habitId?: string; taskId?: string; date?: string };
      if (!body.habitId && !body.taskId) {
        return reply.code(400).send({ error: 'habitId or taskId is required' });
      }
      const res = await todayService.deselectForToday(userId, body.habitId, body.taskId, body.date);
      return res;
    } catch (e: any) {
      return reply.code(400).send({ error: e.message });
    }
  });
}
