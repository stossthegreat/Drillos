"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_plugin_1 = __importDefault(require("fastify-plugin"));
const redis_1 = require("../utils/redis");
const HEADER = 'idempotency-key';
const TTL_SECONDS = 60 * 10; // 10 min window
async function takeLock(key) {
    // SET key value EX ttl NX
    const ok = await redis_1.redis.set(key, '1', 'EX', TTL_SECONDS, 'NX');
    return ok === 'OK';
}
exports.default = (0, fastify_plugin_1.default)(async function idempotencyPlugin(fastify) {
    fastify.decorate('withIdempotency', function (handler, makeKey) {
        return async function wrapped(req, reply) {
            const headerKey = req.headers[HEADER]?.trim();
            const customKey = makeKey ? makeKey(req) : null;
            const key = headerKey || customKey;
            if (!key) {
                // No key supplied: process normally (no mock!)
                return handler(req);
            }
            const namespaced = `idem:${key}`;
            const acquired = await takeLock(namespaced);
            if (!acquired) {
                return reply.code(409).send({ error: 'Duplicate request' });
            }
            return handler(req);
        };
    });
});
