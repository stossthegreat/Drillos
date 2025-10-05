"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const HEADER_USER_ID = 'x-user-id';
exports.default = (0, fastify_plugin_1.default)(async function authPlugin(fastify) {
    fastify.decorateRequest('user', null);
    fastify.addHook('preHandler', async (req, reply) => {
        // 1) Prefer explicit header (mobile/web can set this)
        const headerUser = req.headers[HEADER_USER_ID]?.trim();
        if (headerUser) {
            req.user = { id: headerUser };
            return;
        }
        // 2) Try Bearer JWT if provided
        const auth = req.headers.authorization;
        if (auth && auth.startsWith('Bearer ')) {
            const token = auth.slice('Bearer '.length).trim();
            const secret = process.env.JWT_PUBLIC_KEY || process.env.JWT_SECRET;
            if (!secret) {
                reply.code(500).send({ error: 'Server auth misconfiguration' });
                return;
            }
            try {
                const decoded = jsonwebtoken_1.default.verify(token, secret, {
                    algorithms: process.env.JWT_PUBLIC_KEY ? ['RS256'] : ['HS256'],
                });
                const uid = decoded.sub || decoded.userId || decoded.id;
                if (uid) {
                    req.user = { id: uid };
                    return;
                }
            }
            catch {
                // fall-through
            }
        }
        // 3) Hard-fail (NO DEMO, NO MOCK)
        reply.code(401).send({ error: 'Unauthorized: missing user identity' });
    });
});
//# sourceMappingURL=auth.js.map