// src/controllers/habits.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { habitsService } from '../services/habits.service';

function getUserIdOrThrow(req: any): string {
  // Assumes you have auth middleware that sets req.user.id
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    throw new Error('Unauthorized: missing user id');
  }
  return uid;
}

export default async function habitsRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // GET /v1/habits
  fastify.get('/v1/habits', {
    schema: {
      tags: ['Habits'],
      summary: 'List habits for current user',
      response: { 200: { type: 'array' } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const data = await habitsService.list(userId);
      return data;
    } catch (e: any) {
      req.log.error(e);
      reply.code(e.message?.startsWith('Unauthorized') ? 401 : 500).send({ error: e.message || 'Failed to list habits' });
    }
  });

  // POST /v1/habits
  fastify.post('/v1/habits', {
    schema: {
      tags: ['Habits'],
      summary: 'Create a new habit',
      body: {
        type: 'object',
        required: ['title'],
        properties: {
          title: { type: 'string' },
          schedule: { type: 'object' },
        },
      },
      response: { 201: { type: 'object' } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const body = req.body as any;
      const created = await habitsService.create(userId, { title: body.title, schedule: body.schedule });
      reply.code(201);
      return created;
    } catch (e: any) {
      req.log.error(e);
      reply.code(e.message?.startsWith('Unauthorized') ? 401 : 400).send({ error: e.message || 'Failed to create habit' });
    }
  });

  // PATCH /v1/habits/:id
  fastify.patch('/v1/habits/:id', {
    schema: {
      tags: ['Habits'],
      summary: 'Update habit (title, schedule)',
      params: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' } },
      },
      body: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          schedule: { type: 'object' },
        },
      },
      response: { 200: { type: 'object' } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      const body = req.body as any;
      const updated = await habitsService.update(id, userId, { title: body.title, schedule: body.schedule });
      return updated;
    } catch (e: any) {
      req.log.error(e);
      reply.code(e.message?.includes('not found') ? 404 : e.message?.startsWith('Unauthorized') ? 401 : 400)
        .send({ error: e.message || 'Failed to update habit' });
    }
  });

  // DELETE /v1/habits/:id
  fastify.delete('/v1/habits/:id', {
    schema: {
      tags: ['Habits'],
      summary: 'Delete habit',
      params: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' } },
      },
      response: { 200: { type: 'object' } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      const result = await habitsService.delete(id, userId);
      return result;
    } catch (e: any) {
      req.log.error(e);
      reply.code(e.message?.includes('not found') ? 404 : e.message?.startsWith('Unauthorized') ? 401 : 400)
        .send({ error: e.message || 'Failed to delete habit' });
    }
  });

  // POST /v1/habits/:id/tick
  fastify.post('/v1/habits/:id/tick', {
    schema: {
      tags: ['Habits'],
      summary: 'Tick habit (idempotent per day)',
      params: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' } },
      },
      headers: {
        type: 'object',
        properties: {
          'Idempotency-Key': { type: 'string' },
          'idempotency-key': { type: 'string' },
        },
      },
      response: { 200: { type: 'object' } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      const idem =
        (req.headers['idempotency-key'] as string) ||
        (req.headers['Idempotency-Key'] as unknown as string) ||
        undefined;
      const result = await habitsService.tick(id, userId, idem);
      return result;
    } catch (e: any) {
      req.log.error(e);
      reply.code(e.message?.includes('not found') ? 404 : e.message?.startsWith('Unauthorized') ? 401 : 400)
        .send({ error: e.message || 'Failed to tick habit' });
    }
  });
}
