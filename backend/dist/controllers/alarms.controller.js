"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = alarmsRoutes;
const alarms_service_1 = require("../services/alarms.service");
const db_1 = require("../utils/db");
function getUserIdOrThrow(req) {
    const uid = req?.user?.id || req.headers['x-user-id'];
    if (!uid || typeof uid !== 'string') {
        throw new Error('Unauthorized: missing user id');
    }
    return uid;
}
async function alarmsRoutes(fastify, _opts) {
    // Helper to ensure demo user exists
    async function ensureDemoUser(userId) {
        if (userId === "demo-user-123") {
            const existingUser = await db_1.prisma.user.findUnique({ where: { id: userId } });
            if (!existingUser) {
                await db_1.prisma.user.create({
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
            return await alarms_service_1.alarmsService.list(userId);
        }
        catch (e) {
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
            const body = req.body;
            const alarm = await alarms_service_1.alarmsService.create(userId, body);
            reply.code(201);
            return alarm;
        }
        catch (e) {
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
            const { id } = req.params;
            const body = req.body;
            return await alarms_service_1.alarmsService.update(id, userId, body);
        }
        catch (e) {
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
            const { id } = req.params;
            return await alarms_service_1.alarmsService.delete(id, userId);
        }
        catch (e) {
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
            const { id } = req.params;
            return await alarms_service_1.alarmsService.markFired(id, userId);
        }
        catch (e) {
            reply.code(400).send({ error: e.message });
        }
    });
}
