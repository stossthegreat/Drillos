// src/controllers/alarms.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { alarmsService } from '../services/alarms.service';

function getUserIdOrThrow(req: any): string {
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    throw new Error('Unauthorized: missing user id');
  }
  return uid;
}

export default async function alarmsRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // GET /v1/alarms
  fastify.get('/v1/alarms', {
    schema: { tags: ['Alarms'], summary: 'List alarms', response: { 200: { type: 'array' } } },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      return await alarmsService.list(userId);
    } catch (e: any) {
      reply.code(401).send({ error: e.message });
    }
  });

  // POST /v1/alarms
  fastify.post('/v1/alarms', {
    schema: {
      tags: ['Alarms'],
      summary: 'Create alarm',
      body: {
        type: 'object',
        required: ['label', 'rrule'],
        properties: {
          label: { type: 'string' },
          rrule: { type: 'string' },
          tone: { type: 'string', enum: ['strict', 'balanced', 'light'] },
        },
      },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const body = req.body as any;
      const alarm = await alarmsService.create(userId, body);
      reply.code(201);
      return alarm;
    } catch (e: any) {
      reply.code(400).send({ error: e.message });
    }
  });

  // PATCH /v1/alarms/:id
  fastify.patch('/v1/alarms/:id', {
    schema: {
      tags: ['Alarms'],
      summary: 'Update alarm',
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      const body = req.body as any;
      return await alarmsService.update(id, userId, body);
    } catch (e: any) {
      reply.code(400).send({ error: e.message });
    }
  });

  // DELETE /v1/alarms/:id
  fastify.delete('/v1/alarms/:id', {
    schema: {
      tags: ['Alarms'],
      summary: 'Delete alarm',
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      return await alarmsService.delete(id, userId);
    } catch (e: any) {
      reply.code(400).send({ error: e.message });
    }
  });

  // POST /v1/alarms/:id/fire
  fastify.post('/v1/alarms/:id/fire', {
    schema: {
      tags: ['Alarms'],
      summary: 'Fire alarm (manual or system)',
      params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
    },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      const { id } = req.params as any;
      return await alarmsService.markFired(id, userId);
    } catch (e: any) {
      reply.code(400).send({ error: e.message });
    }
  });
}
