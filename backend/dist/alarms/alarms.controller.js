import { AlarmsService } from './alarms.service';
import { requireAuth } from '../middleware/auth';
const service = new AlarmsService();
export default async function alarmsRoutes(fastify, _opts) {
    fastify.route({
        method: 'GET',
        url: '/v1/alarms',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'List user alarms',
            response: {
                200: {
                    type: 'array',
                    items: { type: 'object' },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const alarms = await service.list(userId);
            reply.send(alarms);
        },
    });
    fastify.route({
        method: 'POST',
        url: '/v1/alarms',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'Create alarm (supports mentor voice + metadata)',
            body: {
                type: 'object',
                required: ['label', 'rrule'],
                properties: {
                    label: { type: 'string', minLength: 1 },
                    rrule: { type: 'string', description: 'RRULE string e.g. FREQ=DAILY;BYHOUR=7;BYMINUTE=0' },
                    tone: { type: 'string', enum: ['strict', 'balanced', 'light'] },
                    enabled: { type: 'boolean', default: true },
                    metadata: {
                        type: 'object',
                        properties: {
                            type: { type: 'string' },
                            habitId: { type: 'string' },
                            taskId: { type: 'string' },
                            mentor: { type: 'string', enum: ['marcus', 'confucius', 'lincoln', 'buddha', 'sergeant'] },
                            presetId: { type: 'string' },
                            text: { type: 'string' },
                        },
                    },
                },
            },
            response: {
                201: { type: 'object' },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const body = req.body;
            const alarm = await service.create(userId, body);
            reply.code(201).send(alarm);
        },
    });
    fastify.route({
        method: 'PATCH',
        url: '/v1/alarms/:id',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'Update alarm (rrule recalculates nextRun)',
            params: {
                type: 'object',
                required: ['id'],
                properties: { id: { type: 'string' } },
            },
            body: {
                type: 'object',
                properties: {
                    label: { type: 'string' },
                    rrule: { type: 'string' },
                    tone: { type: 'string', enum: ['strict', 'balanced', 'light'] },
                    enabled: { type: 'boolean' },
                    metadata: { type: 'object' },
                },
            },
            response: { 200: { type: 'object' } },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { id } = req.params;
            const body = req.body;
            const updated = await service.update(userId, id, body);
            reply.send(updated);
        },
    });
    fastify.route({
        method: 'POST',
        url: '/v1/alarms/:id/fire',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'Manually fire an alarm (generates push + voice if configured)',
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
                        firedAt: { type: 'string' },
                        nextRun: { type: 'string' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { id } = req.params;
            const result = await service.fire(userId, id);
            reply.send(result);
        },
    });
    fastify.route({
        method: 'POST',
        url: '/v1/alarms/:id/dismiss',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'Dismiss/snooze an alarm',
            params: {
                type: 'object',
                required: ['id'],
                properties: { id: { type: 'string' } },
            },
            body: {
                type: 'object',
                properties: {
                    snoozeMinutes: { type: 'number', minimum: 0 },
                },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        ok: { type: 'boolean' },
                        nextRun: { type: 'string' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { id } = req.params;
            const body = req.body;
            const snoozeMinutes = body?.snoozeMinutes ?? 0;
            const result = await service.dismiss(userId, id, snoozeMinutes);
            reply.send(result);
        },
    });
    fastify.route({
        method: 'DELETE',
        url: '/v1/alarms/:id',
        preHandler: requireAuth,
        schema: {
            tags: ['Alarms'],
            summary: 'Delete alarm',
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
                        deleted: { type: 'string' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { id } = req.params;
            const result = await service.remove(userId, id);
            reply.send(result);
        },
    });
}
//# sourceMappingURL=alarms.controller.js.map