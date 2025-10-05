"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redis = void 0;
exports.getRedis = getRedis;
exports.redisHealthCheck = redisHealthCheck;
exports.closeRedis = closeRedis;
// src/utils/redis.ts
const ioredis_1 = __importDefault(require("ioredis"));
const env_1 = require("./env");
const logger_1 = require("./logger");
let client = null;
function makeClient() {
    const c = new ioredis_1.default(env_1.ENV.REDIS_URL, {
        lazyConnect: false,
        maxRetriesPerRequest: null, // Required for BullMQ blocking operations
        enableOfflineQueue: false,
    });
    c.on('connect', () => logger_1.logger.info({ url: maskRedis(env_1.ENV.REDIS_URL) }, '🔌 Redis connected'));
    c.on('error', (err) => logger_1.logger.error({ err }, '🔴 Redis error'));
    c.on('reconnecting', () => logger_1.logger.warn('Redis reconnecting…'));
    c.on('end', () => logger_1.logger.warn('Redis connection closed'));
    return c;
}
function getRedis() {
    if (!client) {
        // reuse in dev hot-reload
        const g = global;
        if (env_1.isDev && g.__redis__) {
            client = g.__redis__;
        }
        else {
            client = makeClient();
            if (env_1.isDev)
                global.__redis__ = client;
        }
    }
    return client;
}
exports.redis = getRedis(); // Export as 'redis' for compatibility
async function redisHealthCheck() {
    try {
        const c = getRedis();
        const pong = await c.ping();
        return pong === 'PONG';
    }
    catch {
        return false;
    }
}
async function closeRedis() {
    if (client) {
        try {
            await client.quit();
        }
        catch {
            await client.disconnect();
        }
        client = null;
    }
}
function maskRedis(url) {
    try {
        const u = new URL(url);
        if (u.password)
            u.password = '***';
        return u.toString();
    }
    catch {
        return 'redis://***';
    }
}
