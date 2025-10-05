"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// src/plugins/auth.plugin.ts
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
exports.default = (0, fastify_plugin_1.default)(async (fastify) => {
    fastify.decorateRequest('user', null);
    fastify.addHook('preHandler', async (req, reply) => {
        const auth = req.headers['authorization'];
        if (!auth?.startsWith('Bearer ')) {
            return reply.code(401).send({ error: 'Unauthorized: missing token' });
        }
        try {
            const token = auth.replace('Bearer ', '');
            const decoded = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
            req.user = {
                id: decoded.sub,
                email: decoded.email,
                plan: decoded.plan ?? 'FREE',
                mentorId: decoded.mentorId ?? 'drill',
            };
        }
        catch (err) {
            return reply.code(401).send({ error: 'Unauthorized: invalid token' });
        }
    });
});
//# sourceMappingURL=auth.plugin.js.map