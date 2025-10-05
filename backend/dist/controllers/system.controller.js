"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.systemController = systemController;
const db_1 = require("../utils/db");
const health_1 = require("../utils/health");
async function systemController(fastify) {
    fastify.get('/v1/system/alerts', async (req, reply) => {
        const userId = req.user?.id || 'system';
        const alerts = await db_1.prisma.event.findMany({
            where: { type: 'system_alert', userId },
            orderBy: { ts: 'desc' },
            take: 10,
        });
        return alerts;
    });
    fastify.get('/v1/system/health', async () => {
        return await (0, health_1.checkDependencies)();
    });
}
