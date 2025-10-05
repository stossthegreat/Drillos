import { BriefService } from './brief.service';
import { requireAuth } from '../middleware/auth';
const service = new BriefService();
export default async function briefRoutes(fastify, _opts) {
    fastify.route({
        method: 'GET',
        url: '/v1/brief/today',
        preHandler: requireAuth,
        schema: {
            tags: ['Brief'],
            summary: 'Get Morning Brief (missions, nudges, risk banners)',
            response: {
                200: {
                    type: 'object',
                    properties: {
                        missions: { type: 'array' },
                        riskBanners: { type: 'array' },
                        nudges: { type: 'array' },
                        weeklyTarget: { type: 'object' },
                        sentiment: { type: 'object' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const brief = await service.getMorningBrief(userId);
            reply.send(brief);
        },
    });
    fastify.route({
        method: 'GET',
        url: '/v1/brief/evening',
        preHandler: requireAuth,
        schema: {
            tags: ['Brief'],
            summary: 'Get Evening Debrief (reflection + completion)',
            response: {
                200: {
                    type: 'object',
                    properties: {
                        completed: { type: 'number' },
                        total: { type: 'number' },
                        completion: { type: 'number' },
                        reflections: { type: 'array' },
                        suggestion: { type: 'string' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const brief = await service.getEveningBrief(userId);
            reply.send(brief);
        },
    });
    fastify.route({
        method: 'GET',
        url: '/v1/brief/ensure-alarms',
        preHandler: requireAuth,
        schema: {
            tags: ['Brief'],
            summary: 'Ensure daily Morning/Evening brief alarms exist',
            querystring: {
                type: 'object',
                properties: {
                    tz: { type: 'string', default: 'Europe/London' },
                },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        ok: { type: 'boolean' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { tz } = req.query;
            const result = await service.ensureDailyBriefAlarms(userId, tz || 'Europe/London');
            reply.send(result);
        },
    });
    fastify.route({
        method: 'GET',
        url: '/v1/brief/push-morning',
        preHandler: requireAuth,
        schema: {
            tags: ['Brief'],
            summary: 'Trigger Morning Brief push now (dev tool)',
            querystring: {
                type: 'object',
                properties: {
                    fcm: { type: 'string' },
                },
            },
            response: {
                200: {
                    type: 'object',
                    properties: {
                        ok: { type: 'boolean' },
                    },
                },
            },
        },
        handler: async (req, reply) => {
            const userId = req.user.id;
            const { fcm } = req.query;
            const result = await service.pushMorningBrief(userId, fcm);
            reply.send(result);
        },
    });
}
//# sourceMappingURL=brief.controller.js.map