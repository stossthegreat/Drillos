// src/server.ts
import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUI from '@fastify/swagger-ui';
import dotenv from 'dotenv';

import { prisma } from './utils/db';
import { redis, getRedis } from './utils/redis';
import OpenAI from 'openai';
import Stripe from 'stripe';
import admin from 'firebase-admin';

// controllers
import { habitsController } from './controllers/habits.controller';
import alarmsController from './controllers/alarms.controller';
import { streaksController } from './controllers/streaks.controller';
import { eventsController } from './controllers/events.controller';
import { nudgesController } from './controllers/nudges.controller';
import briefController from './controllers/brief.controller';
import { tasksController } from './controllers/tasks.controller';
import voiceController from './controllers/voice.controller';
import aiController from './controllers/ai.controller';
import { userController } from './controllers/user.controller';

// schedulers
import { bootstrapSchedulers } from './jobs/scheduler';
import './workers/scheduler.worker'; // ⚡ Import worker to instantiate it

// load .env
dotenv.config();

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
  const results: Record<string, any> = {};

  if (process.env.DATABASE_URL) {
    try {
      await prisma.$queryRaw`SELECT 1`;
      results.postgres = 'ok';
    } catch (e: any) {
      results.postgres = `error: ${e.message}`;
    }
  } else results.postgres = 'skipped (no DATABASE_URL)';

  if (process.env.REDIS_URL) {
    try {
      const redisClient = getRedis();
      await redisClient.ping();
      results.redis = 'ok';
    } catch (e: any) {
      results.redis = `error: ${e.message}`;
    }
  } else results.redis = 'skipped (no REDIS_URL)';

  if (process.env.OPENAI_API_KEY) {
    try {
      const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
      await client.models.list();
      results.openai = 'ok';
    } catch (e: any) {
      results.openai = `error: ${e.message}`;
    }
  } else results.openai = 'skipped (no API key)';

  if (process.env.ELEVENLABS_API_KEY) {
    try {
      const res = await fetch('https://api.elevenlabs.io/v1/voices', {
        headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY },
      });
      results.elevenlabs = res.ok ? 'ok' : 'error';
    } catch (e: any) {
      results.elevenlabs = `error: ${e.message}`;
    }
  } else results.elevenlabs = 'skipped (no API key)';

  if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
    try {
      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          }),
        });
      }
      results.firebase = 'ok';
    } catch (e: any) {
      results.firebase = `error: ${e.message}`;
    }
  } else results.firebase = 'skipped (no credentials)';

  if (process.env.STRIPE_SECRET_KEY) {
    try {
      const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2025-08-27.basil' });
      await stripe.accounts.retrieve();
      results.stripe = 'ok';
    } catch (e: any) {
      results.stripe = `error: ${e.message}`;
    }
  } else results.stripe = 'skipped (no API key)';

  return results;
}

// ✅ Build Fastify server (FULL + FIX)
const buildServer = () => {
  const fastify = Fastify({ logger: true });

  // ✅ FIX: allow empty JSON bodies for DELETE / PATCH / etc
  fastify.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body: any, done) => {
    if (!body) return done(null, {}); // Treat empty as {}
    try {
      const json = JSON.parse(body);
      done(null, json);
    } catch (err: any) {
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
  fastify.register(cors, { 
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'idempotency-key'],
    credentials: true,
  });
  fastify.register(swagger, {
    openapi: {
      openapi: '3.0.0',
      info: { title: 'HabitOS API', version: '1.0.0', description: 'Full-scale DrillSergeant / HabitOS API' },
      servers: [{ url: process.env.BACKEND_PUBLIC_URL || 'http://localhost:8080' }],
    },
  });
  fastify.register(swaggerUI, { routePrefix: '/docs', uiConfig: { docExpansion: 'full', deepLinking: false } });

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
  fastify.register(habitsController);
  fastify.register(alarmsController);
  fastify.register(streaksController);
  fastify.register(eventsController);
  fastify.register(nudgesController);
  fastify.register(briefController);
  fastify.register(tasksController);
  fastify.register(voiceController);
  fastify.register(aiController);
  fastify.register(userController);

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
    setImmediate(() => bootstrapSchedulers().catch(console.error));
  } catch (err) {
    console.error('❌ Server startup failed:', err);
    process.exit(1);
  }
};

// ✅ Graceful shutdown
process.on('SIGINT', async () => {
  console.log('⏹️ Shutting down gracefully...');
  await prisma.$disconnect();
  await getRedis().quit();
  process.exit(0);
});

start();
