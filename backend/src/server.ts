import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUI from '@fastify/swagger-ui';
import dotenv from 'dotenv';

import { prisma } from './utils/db';
import { redis } from './utils/redis';
import OpenAI from 'openai';
import Stripe from 'stripe';
import admin from 'firebase-admin';

// controllers
import { habitsController } from './controllers/habits.controller';
import { alarmsController } from './controllers/alarms.controller';
import { streaksController } from './controllers/streaks.controller';
import { eventsController } from './controllers/events.controller';
import { nudgesController } from './controllers/nudges.controller';
import { briefController } from './controllers/brief.controller';
import { voiceController } from './controllers/voice.controller';
import { userController } from './controllers/user.controller';

// load .env
dotenv.config();

function validateEnv() {
  const required = [
    'DATABASE_URL',
    'REDIS_URL',
    'OPENAI_API_KEY',
    'OPENAI_MODEL',
    'ELEVENLABS_API_KEY',
    'ELEVENLABS_VOICE_MARCUS',
    'ELEVENLABS_VOICE_DRILL',
    'ELEVENLABS_VOICE_CONFUCIUS',
    'ELEVENLABS_VOICE_LINCOLN',
    'ELEVENLABS_VOICE_BUDDHA',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY',
    'STRIPE_SECRET_KEY',
    'STRIPE_WEBHOOK_SECRET',
    'S3_ENDPOINT',
    'S3_BUCKET',
    'S3_ACCESS_KEY',
    'S3_SECRET_KEY',
  ];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    console.error('❌ Missing required env vars:', missing.join(', '));
    process.exit(1);
  }
  console.log('✅ Env vars validated.');
}

// Startup check logic
async function runStartupChecks() {
  const results: Record<string, any> = {};

  try {
    await prisma.$queryRaw`SELECT 1`;
    results.postgres = 'ok';
  } catch (e: any) {
    results.postgres = `error: ${e.message}`;
  }

  try {
    await redis.ping();
    results.redis = 'ok';
  } catch (e: any) {
    results.redis = `error: ${e.message}`;
  }

  try {
    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    await client.models.list();
    results.openai = 'ok';
  } catch (e: any) {
    results.openai = `error: ${e.message}`;
  }

  try {
    const res = await fetch('https://api.elevenlabs.io/v1/voices', {
      headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY! },
    });
    if (res.ok) results.elevenlabs = 'ok';
    else throw new Error(await res.text());
  } catch (e: any) {
    results.elevenlabs = `error: ${e.message}`;
  }

  try {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        }),
      });
    }
    await admin.app().options.projectId; // quick check
    results.firebase = 'ok';
  } catch (e: any) {
    results.firebase = `error: ${e.message}`;
  }

  try {
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2022-11-15' });
    await stripe.accounts.retrieve();
    results.stripe = 'ok';
  } catch (e: any) {
    results.stripe = `error: ${e.message}`;
  }

  return results;
}

const buildServer = () => {
  const fastify = Fastify({ logger: true });

  fastify.register(cors, { origin: true });

  fastify.register(swagger, {
    openapi: {
      openapi: '3.0.0',
      info: { title: 'HabitOS API', version: '1.0.0', description: 'The full-scale DrillSergeant / HabitOS API' },
      servers: [{ url: process.env.BACKEND_PUBLIC_URL || 'http://localhost:8080' }],
    },
  });
  fastify.register(swaggerUI, { routePrefix: '/docs', uiConfig: { docExpansion: 'full', deepLinking: false } });

  fastify.get('/health', async () => ({ ok: true, ts: new Date().toISOString() }));

  // new: startup-check
  fastify.get('/startup-check', async () => {
    const checks = await runStartupChecks();
    return { ok: Object.values(checks).every((v) => v === 'ok'), checks };
  });

  // controllers
  fastify.register(habitsController);
  fastify.register(alarmsController);
  fastify.register(streaksController);
  fastify.register(eventsController);
  fastify.register(nudgesController);
  fastify.register(briefController);
  fastify.register(voiceController);
  fastify.register(userController);

  return fastify;
};

const start = async () => {
  validateEnv();
  const server = buildServer();
  try {
    const port = process.env.PORT ? Number(process.env.PORT) : 8080;
    await server.listen({ port, host: process.env.HOST || '0.0.0.0' });
    console.log(`🚀 HabitOS API running at ${process.env.BACKEND_PUBLIC_URL || `http://localhost:${port}`}`);
    console.log('📖 Docs available at /docs');
    console.log('🩺 Run /startup-check to verify integrations');
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
