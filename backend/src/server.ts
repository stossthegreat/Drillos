import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUI from '@fastify/swagger-ui';
import { prisma } from './utils/db';
import { redis } from './utils/redis';
import { checkQueueHealth, closeAllQueues } from './utils/queues';

// controllers
import { habitsController } from './controllers/habits.controller';
import { alarmsController } from './controllers/alarms.controller';
import { streaksController } from './controllers/streaks.controller';
import { eventsController } from './controllers/events.controller';
import { nudgesController } from './controllers/nudges.controller';
import { briefController } from './controllers/brief.controller';
import { voiceController } from './controllers/voice.controller';
import { userController } from './controllers/user.controller';

const buildServer = () => {
  const fastify = Fastify({
    logger: {
      transport: {
        target: 'pino-pretty',
        options: { translateTime: 'SYS:standard', ignore: 'pid,hostname' },
      },
    },
    trustProxy: true,
  });

  // CORS
  fastify.register(cors, {
    origin: process.env.CORS_ORIGIN?.split(',') || '*',
    credentials: true,
  });

  // Swagger docs
  fastify.register(swagger, {
    openapi: {
      openapi: '3.0.0',
      info: {
        title: 'HabitOS API',
        version: '1.0.0',
        description: 'The full-scale DrillSergeant / HabitOS API',
      },
      servers: [{ url: process.env.BACKEND_PUBLIC_URL || 'http://localhost:8080' }],
    },
  });
  fastify.register(swaggerUI, {
    routePrefix: '/docs',
    uiConfig: { docExpansion: 'list', deepLinking: true },
  });

  // Health endpoints
  fastify.get('/health', async () => ({ ok: true, ts: new Date().toISOString() }));
  fastify.get('/ready', async () => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      await redis.ping();
      const queues = await checkQueueHealth();
      return { ok: true, db: true, redis: true, queues };
    } catch (err: any) {
      return { ok: false, error: err.message || String(err) };
    }
  });

  // Controllers (API routes)
  fastify.register(habitsController, { prefix: '/api/v1' });
  fastify.register(alarmsController, { prefix: '/api/v1' });
  fastify.register(streaksController, { prefix: '/api/v1' });
  fastify.register(eventsController, { prefix: '/api/v1' });
  fastify.register(nudgesController, { prefix: '/api/v1' });
  fastify.register(briefController, { prefix: '/api/v1' });
  fastify.register(voiceController, { prefix: '/api/v1' });
  fastify.register(userController, { prefix: '/api/v1' });

  return fastify;
};

const start = async () => {
  const server = buildServer();
  const port = Number(process.env.PORT) || 8080;
  const host = process.env.HOST || '0.0.0.0';

  try {
    await server.listen({ port, host });
    console.log(`🚀 HabitOS API running at http://${host}:${port}`);
    console.log(`📖 Swagger docs at http://${host}:${port}/docs`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }

  // Graceful shutdown
  const shutdown = async () => {
    console.log('🛑 Shutting down gracefully...');
    await closeAllQueues();
    await prisma.$disconnect();
    await redis.quit();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
};

start();
