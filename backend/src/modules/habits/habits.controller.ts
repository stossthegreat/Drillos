import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import HabitsService, { CreateHabitInput, UpdateHabitInput } from './habits.service';
import { requireAuth } from '../../middleware/auth';

// Optional: if you want to share a single service instance, you can init here.
// Otherwise, HabitsService constructs its own Prisma/Redis if not passed.
const service = new HabitsService();

export default async function habitsRoutes(fastify: FastifyInstance, _opts: FastifyPluginOptions) {
  // --------- GET /v1/habits (list) ----------
  fastify.route({
    method: 'GET',
    url: '/v1/habits',
    preHandler: requireAuth,
    schema: {
      tags: ['Habits'],
      summary: 'List user habits scheduled for the given day (default: today)',
      querystring: {
        type: 'object',
        properties: {
          date: { type: 'string', description: 'ISO date string (optional)' },
        },
      },
      response: {
        200: {
          type: 'array',
          items: { type: 'object' },
        },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user!.id;
      const date = (req.query as any)?.date as string | undefined;
      const rows = await service.list(userId, date);
      reply.send(rows);
    },
  });

  // --------- POST /v1/habits (create) ----------
  fastify.route({
    method: 'POST',
    url: '/v1/habits',
    preHandler: requireAuth,
    schema: {
      tags: ['Habits'],
      summary: 'Create a new habit',
      body: {
        type: 'object',
        required: ['title', 'schedule'],
        properties: {
          title: { type: 'string', minLength: 1 },
          schedule: { type: 'object' }, // validated in service.normalizeSchedule
          color: { type: 'string' },
          context: { type: 'object' },
          reminderEnabled: { type: 'boolean' },
          reminderTime: { type: 'string', pattern: '^[0-2]\\d:[0-5]\\d$' }, // "HH:mm"
        },
      },
      response: {
        201: { type: 'object' },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user!.id;
      const body = req.body as Omit<CreateHabitInput, 'userId'>;
      const created = await service.create({ userId, ...body });
      reply.code(201).send(created);
    },
  });

  // --------- PATCH /v1/habits/:id (update) ----------
  fastify.route({
    method: 'PATCH',
    url: '/v1/habits/:id',
    preHandler: requireAuth,
    schema: {
      tags: ['Habits'],
      summary: 'Update a habit',
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
          color: { type: 'string' },
          context: { type: 'object' },
          reminderEnabled: { type: 'boolean' },
          reminderTime: { type: 'string', pattern: '^[0-2]\\d:[0-5]\\d$' },
        },
      },
      response: { 200: { type: 'object' } },
    },
    handler: async (req, reply) => {
      const userId = req.user!.id;
      const { id } = req.params as any;
      const updates = req.body as UpdateHabitInput;
      const updated = await service.update(id, userId, updates);
      reply.send(updated);
    },
  });

  // --------- DELETE /v1/habits/:id (delete) ----------
  fastify.route({
    method: 'DELETE',
    url: '/v1/habits/:id',
    preHandler: requireAuth,
    schema: {
      tags: ['Habits'],
      summary: 'Delete a habit',
      params: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' } },
      },
      response: {
        200: {
          type: 'object',
          properties: {
            ok: { type: 'boolean' },
            deleted: { type: 'object' },
          },
        },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user!.id;
      const { id } = req.params as any;
      const result = await service.delete(id, userId);
      reply.send(result);
    },
  });

  // --------- POST /v1/habits/:id/tick (idempotent complete) ----------
  fastify.route({
    method: 'POST',
    url: '/v1/habits/:id/tick',
    preHandler: requireAuth,
    schema: {
      tags: ['Habits'],
      summary: 'Mark a habit complete for today (idempotent; respects schedule and timezone)',
      params: {
        type: 'object',
        required: ['id'],
        properties: { id: { type: 'string' } },
      },
      headers: {
        type: 'object',
        properties: {
          'idempotency-key': { type: 'string' },
        },
      },
      body: {
        type: 'object',
        properties: {
          dateISO: { type: 'string', description: 'Override date (ISO) for testing/backfill' },
        },
      },
      response: {
        200: {
          type: 'object',
          properties: {
            ok: { type: 'boolean' },
            idempotent: { type: 'boolean' },
            streak: { type: 'number' },
            timestamp: { type: 'string' },
            message: { type: 'string' },
          },
        },
      },
    },
    handler: async (req, reply) => {
      const userId = req.user!.id;
      const { id } = req.params as any;
      const idempotencyKey = (req.headers['idempotency-key'] as string) || undefined;
      const dateISO = (req.body as any)?.dateISO as string | undefined;

      const result = await service.tick(id, userId, { 
        ...(idempotencyKey && { idempotencyKey }), 
        ...(dateISO && { dateISO })
      });
      reply.send(result);
    },
  });
}
