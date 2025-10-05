"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// src/server.ts
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const swagger_1 = __importDefault(require("@fastify/swagger"));
const swagger_ui_1 = __importDefault(require("@fastify/swagger-ui"));
const dotenv_1 = __importDefault(require("dotenv"));
const db_1 = require("./utils/db");
const redis_1 = require("./utils/redis");
const openai_1 = __importDefault(require("openai"));
const stripe_1 = __importDefault(require("stripe"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
// controllers
const habits_controller_1 = require("./controllers/habits.controller");
const alarms_controller_1 = __importDefault(require("./controllers/alarms.controller"));
const streaks_controller_1 = require("./controllers/streaks.controller");
const events_controller_1 = require("./controllers/events.controller");
const nudges_controller_1 = require("./controllers/nudges.controller");
const brief_controller_1 = __importDefault(require("./controllers/brief.controller"));
const tasks_controller_1 = require("./controllers/tasks.controller");
const voice_controller_1 = __importDefault(require("./controllers/voice.controller"));
const ai_controller_1 = __importDefault(require("./controllers/ai.controller"));
const user_controller_1 = require("./controllers/user.controller");
// schedulers
const scheduler_1 = require("./jobs/scheduler");
require("./workers/scheduler.worker"); // ⚡ Import worker to instantiate it
// load .env
dotenv_1.default.config();
// ✅ Validate env vars before boot
function validateEnv() {
    if (process.env.NODE_ENV === 'build' || process.env.RAILWAY_ENVIRONMENT === 'build') {
        console.log('⏭️ Skipping env validation during build process');
        return;
    }
    const required = [];
    if (!process.env.RAILWAY_ENVIRONMENT) {
        required.push('DATABASE_URL', 'REDIS_URL');
    }
    const missing = required.filter((key) => !process.env[key]);
    if (missing.length > 0) {
        console.error('❌ Missing critical env vars:', missing.join(', '));
        process.exit(1);
    }
    const optional = [
        'OPENAI_API_KEY',
        'ELEVENLABS_API_KEY',
        'FIREBASE_PROJECT_ID',
        'STRIPE_SECRET_KEY',
        'S3_ENDPOINT',
    ];
    const missingOptional = optional.filter((key) => !process.env[key]);
    if (missingOptional.length > 0) {
        console.warn('⚠️ Missing optional env vars (some features may not work):', missingOptional.join(', '));
    }
    console.log('✅ Core env vars validated.');
}
// ✅ Startup integration checks
async function runStartupChecks() {
    const results = {};
    if (process.env.DATABASE_URL) {
        try {
            await db_1.prisma.$queryRaw `SELECT 1`;
            results.postgres = 'ok';
        }
        catch (e) {
            results.postgres = `error: ${e.message}`;
        }
    }
    else
        results.postgres = 'skipped (no DATABASE_URL)';
    if (process.env.REDIS_URL) {
        try {
            const redisClient = (0, redis_1.getRedis)();
            await redisClient.ping();
            results.redis = 'ok';
        }
        catch (e) {
            results.redis = `error: ${e.message}`;
        }
    }
    else
        results.redis = 'skipped (no REDIS_URL)';
    if (process.env.OPENAI_API_KEY) {
        try {
            const client = new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
            await client.models.list();
            results.openai = 'ok';
        }
        catch (e) {
            results.openai = `error: ${e.message}`;
        }
    }
    else
        results.openai = 'skipped (no API key)';
    if (process.env.ELEVENLABS_API_KEY) {
        try {
            const res = await fetch('https://api.elevenlabs.io/v1/voices', {
                headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY },
            });
            results.elevenlabs = res.ok ? 'ok' : 'error';
        }
        catch (e) {
            results.elevenlabs = `error: ${e.message}`;
        }
    }
    else
        results.elevenlabs = 'skipped (no API key)';
    if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
        try {
            if (!firebase_admin_1.default.apps.length) {
                firebase_admin_1.default.initializeApp({
                    credential: firebase_admin_1.default.credential.cert({
                        projectId: process.env.FIREBASE_PROJECT_ID,
                        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
                    }),
                });
            }
            results.firebase = 'ok';
        }
        catch (e) {
            results.firebase = `error: ${e.message}`;
        }
    }
    else
        results.firebase = 'skipped (no credentials)';
    if (process.env.STRIPE_SECRET_KEY) {
        try {
            const stripe = new stripe_1.default(process.env.STRIPE_SECRET_KEY, { apiVersion: '2025-08-27.basil' });
            await stripe.accounts.retrieve();
            results.stripe = 'ok';
        }
        catch (e) {
            results.stripe = `error: ${e.message}`;
        }
    }
    else
        results.stripe = 'skipped (no API key)';
    return results;
}
// ✅ Build Fastify server (FULL + FIX)
const buildServer = () => {
    const fastify = (0, fastify_1.default)({ logger: true });
    // ✅ FIX: allow empty JSON bodies for DELETE / PATCH / etc
    fastify.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body, done) => {
        if (!body)
            return done(null, {}); // Treat empty as {}
        try {
            const json = JSON.parse(body);
            done(null, json);
        }
        catch (err) {
            err.statusCode = 400;
            done(err);
        }
    });
    // ✅ Optional safety: strip JSON content-type for empty GET/DELETE
    fastify.addHook('onRequest', (req, _reply, done) => {
        if ((req.method === 'DELETE' || req.method === 'GET') &&
            (req.headers['content-type'] || '').includes('application/json') &&
            !req.headers['content-length']) {
            delete req.headers['content-type'];
        }
        done();
    });
    // ✅ CORS + Docs
    fastify.register(cors_1.default, {
        origin: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'idempotency-key'],
        credentials: true,
    });
    fastify.register(swagger_1.default, {
        openapi: {
            openapi: '3.0.0',
            info: { title: 'HabitOS API', version: '1.0.0', description: 'Full-scale DrillSergeant / HabitOS API' },
            servers: [{ url: process.env.BACKEND_PUBLIC_URL || 'http://localhost:8080' }],
        },
    });
    fastify.register(swagger_ui_1.default, { routePrefix: '/docs', uiConfig: { docExpansion: 'full', deepLinking: false } });
    // ✅ Routes
    fastify.get('/', async () => ({
        message: 'HabitOS API is running',
        docs: '/docs',
        health: '/health',
        status: 'ok',
    }));
    fastify.get('/health', async () => ({
        ok: true,
        status: 'healthy',
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
    }));
    fastify.get('/startup-check', async () => {
        const checks = await runStartupChecks();
        return { ok: Object.values(checks).every((v) => v === 'ok'), checks };
    });
    // ✅ Controllers
    fastify.register(habits_controller_1.habitsController);
    fastify.register(alarms_controller_1.default);
    fastify.register(streaks_controller_1.streaksController);
    fastify.register(events_controller_1.eventsController);
    fastify.register(nudges_controller_1.nudgesController);
    fastify.register(brief_controller_1.default);
    fastify.register(tasks_controller_1.tasksController);
    fastify.register(voice_controller_1.default);
    fastify.register(ai_controller_1.default);
    fastify.register(user_controller_1.userController);
    return fastify;
};
// ✅ Start server
const start = async () => {
    try {
        console.log('🚀 Starting HabitOS API...');
        validateEnv();
        const server = buildServer();
        const port = process.env.PORT ? Number(process.env.PORT) : 8080;
        const host = process.env.HOST || '0.0.0.0';
        await server.listen({ port, host });
        console.log(`✅ Running at ${process.env.BACKEND_PUBLIC_URL || `http://localhost:${port}`}`);
        console.log('📖 Docs: /docs | 🩺 Health: /health | ⏰ Schedulers active');
        setImmediate(() => (0, scheduler_1.bootstrapSchedulers)().catch(console.error));
    }
    catch (err) {
        console.error('❌ Server startup failed:', err);
        process.exit(1);
    }
};
// ✅ Graceful shutdown
process.on('SIGINT', async () => {
    console.log('⏹️ Shutting down gracefully...');
    await db_1.prisma.$disconnect();
    await (0, redis_1.getRedis)().quit();
    process.exit(0);
});
start();
