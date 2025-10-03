// src/controllers/alarms.controller.ts
import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { alarmsService } from '../services/alarms.service';
import { prisma } from '../utils/db';

function getUserIdOrThrow(req: any): string {
  const uid = req?.user?.id || req.headers['x-user-id'];
  if (!uid || typeof uid !== 'string') {
    throw new Error('Unauthorized: missing user id');
  }
  return uid;
}

export default async function alarmsRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  
  // Helper to ensure demo user exists
  async function ensureDemoUser(userId: string) {
    if (userId === "demo-user-123") {
      const existingUser = await prisma.user.findUnique({ where: { id: userId } });
      if (!existingUser) {
        await prisma.user.create({
          data: {
            id: userId,
            email: "demo@drillsergeant.com",
            tz: "Europe/London",
            tone: "balanced",
            intensity: 2,
            consentRoast: false,
            plan: "FREE",
            mentorId: "marcus",
            nudgesEnabled: true,
            briefsEnabled: true,
            debriefsEnabled: true,
          },
        });
        console.log("✅ Created demo user:", userId);
      }
    }
  }
  
  // GET /v1/alarms
  fastify.get('/v1/alarms', {
    schema: { tags: ['Alarms'], summary: 'List alarms', response: { 200: { type: 'array' }, 401: { type: 'object' } } },
  }, async (req, reply) => {
    try {
      const userId = getUserIdOrThrow(req);
      await ensureDemoUser(userId);
      return await alarmsService.list(userId);
    } catch (e: any) {
      return reply.code(401).send({ error: e.message });
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
      await ensureDemoUser(userId);
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
