import Fastify from "fastify";
import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUI from "@fastify/swagger-ui";
import { PrismaClient } from "@prisma/client";
import Redis from "ioredis";
import { Queue } from "bullmq";
import dotenv from "dotenv";
import habitsRoutes from "./modules/habits/habits.controller";
import alarmsRoutes from "./alarms/alarms.controller";
import briefRoutes from "./brief/brief.controller";
import voiceRoutes from "./voice/voice.controller";

// Load env
dotenv.config();

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

// Queues
const notificationQueue = new Queue("notifications", { connection: redis });
const voiceQueue = new Queue("voice", { connection: redis });
const analyticsQueue = new Queue("analytics", { connection: redis });

const buildServer = async () => {
  const fastify = Fastify({
    logger: true,
  });

  // CORS
  await fastify.register(cors, { origin: true });

  // Swagger
  await fastify.register(swagger, {
    openapi: {
      openapi: "3.0.0",
      info: { title: "Habit OS API", version: "1.0.0" },
      servers: [{ url: `http://localhost:${process.env.PORT || 8080}` }],
      components: {
        securitySchemes: {
          bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
        },
      },
    },
  });
  await fastify.register(swaggerUI, {
    routePrefix: "/docs",
    uiConfig: { docExpansion: "full", deepLinking: false },
  });

  // Health check
  fastify.get("/health", async () => ({ ok: true, ts: new Date().toISOString() }));

  // Register routes
  await fastify.register(habitsRoutes);
  await fastify.register(alarmsRoutes);
  await fastify.register(briefRoutes);
  await fastify.register(voiceRoutes);

  // Graceful shutdown
  fastify.addHook("onClose", async () => {
    await prisma.$disconnect();
    await redis.quit();
    await notificationQueue.close();
    await voiceQueue.close();
    await analyticsQueue.close();
  });

  return fastify;
};

const start = async () => {
  const fastify = await buildServer();
  try {
    const port = Number(process.env.PORT) || 8080;
    await fastify.listen({ port, host: "0.0.0.0" });
    console.log(`🚀 Habit OS API running at http://localhost:${port}`);
    console.log(`📚 Swagger docs at http://localhost:${port}/docs`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();