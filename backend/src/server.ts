import Fastify from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUI from '@fastify/swagger-ui';

// controllers
import { habitsController } from './controllers/habits.controller';
import { alarmsController } from './controllers/alarms.controller';
import { streaksController } from './controllers/streaks.controller';
import { eventsController } from './controllers/events.controller';
import { nudgesController } from './controllers/nudges.controller';
import { briefController } from './controllers/brief.controller';
import { voiceController } from './controllers/voice.controller';

const buildServer = () => {
  const fastify = Fastify({
    logger: true
  });

  // enable CORS
  fastify.register(cors, { origin: true });

  // swagger docs
  fastify.register(swagger, {
    openapi: {
      openapi: '3.0.0',
      info: {
        title: 'HabitOS API',
        version: '1.0.0',
        description: 'The full-scale DrillSergeant / HabitOS API'
      },
      servers: [{ url: 'http://localhost:8080' }]
    }
  });
  fastify.register(swaggerUI, {
    routePrefix: '/docs',
    uiConfig: { docExpansion: 'full', deepLinking: false }
  });

  // health
  fastify.get('/health', async () => ({ ok: true, ts: new Date().toISOString() }));

  // controllers
  fastify.register(habitsController);
  fastify.register(alarmsController);
  fastify.register(streaksController);
  fastify.register(eventsController);
  fastify.register(nudgesController);
  fastify.register(briefController);
  fastify.register(voiceController);

  return fastify;
};

const start = async () => {
  const server = buildServer();
  try {
    await server.listen({ port: process.env.PORT ? Number(process.env.PORT) : 8080, host: '0.0.0.0' });
    console.log('🚀 HabitOS API running at http://localhost:8080');
    console.log('📖 Docs available at http://localhost:8080/docs');
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
