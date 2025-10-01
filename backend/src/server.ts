import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUI from '@fastify/swagger-ui';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

import { habitsRoutes } from './controllers/habits.controller';
import { alarmsRoutes } from './controllers/alarms.controller';
import { briefRoutes } from './controllers/brief.controller';

const server = Fastify({ logger: true });

// === Core Services ===
export const prisma = new PrismaClient();
export const redis = new Redis(process.env.REDIS_URL!);

// === Plugins ===
server.register(cors, { origin: true });

server.register(swagger, {
  openapi: {
    openapi: '3.0.0',
    info: { title: 'DrillSergeant API', version: '1.0.0' },
    servers: [{ url: process.env.BASE_URL || 'http://localhost:8080' }]
  }
});
server.register(swaggerUI, {
  routePrefix: '/docs',
  uiConfig: { docExpansion: 'full', deepLinking: false }
});

// === Routes ===
server.register(habitsRoutes, { prefix: '/api/v1/habits' });
server.register(alarmsRoutes, { prefix: '/api/v1/alarms' });
server.register(briefRoutes, { prefix: '/api/v1/brief' });

// === Healthcheck ===
server.get('/health', async () => ({ ok: true, ts: new Date().toISOString() }));

// === Start ===
const start = async () => {
  try {
    await prisma.$connect();
    console.log('✅ Connected to Postgres');

    await redis.ping();
    console.log('✅ Connected to Redis');

    await server.listen({ port: Number(process.env.PORT) || 8080, host: '0.0.0.0' });
    console.log(`🚀 Server running on ${process.env.BASE_URL || 'http://localhost:8080'}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();

export default server;
