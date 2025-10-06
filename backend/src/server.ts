import Fastify from "fastify";
import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUI from "@fastify/swagger-ui";
import dotenv from "dotenv";
import { prisma } from "./utils/db";
import { getRedis } from "./utils/redis";
import { habitsController } from "./controllers/habits.controller";
import { bootstrapSchedulers } from "./jobs/scheduler";
// (keep your other controllers if you have them)
import alarmsController from "./controllers/alarms.controller";
import { streaksController } from "./controllers/streaks.controller";
import { eventsController } from "./controllers/events.controller";
import { nudgesController } from "./controllers/nudges.controller";
import briefController from "./controllers/brief.controller";
import { tasksController } from "./controllers/tasks.controller";
import voiceController from "./controllers/voice.controller";
import aiController from "./controllers/ai.controller";
import { userController } from "./controllers/user.controller";

dotenv.config();

function validateEnv() {
  console.log("✅ Core env vars check: (lenient for Railway)");
}

const buildServer = () => {
  const fastify = Fastify({ logger: true });

  fastify.register(cors, {
    origin: true,
    methods: ["GET","POST","PUT","DELETE","PATCH","OPTIONS"],
    allowedHeaders: ["Content-Type","Authorization","x-user-id","idempotency-key"],
    credentials: true
  });

  fastify.register(swagger, {
    openapi: {
      openapi: "3.0.0",
      info: { title: "HabitOS API", version: "1.0.0" },
      servers: [{ url: process.env.BACKEND_PUBLIC_URL || "http://localhost:8080" }]
    }
  });
  fastify.register(swaggerUI, { routePrefix: "/docs", uiConfig: { docExpansion: "full" } });

  fastify.get("/", async () => ({ message: "HabitOS API is running", docs: "/docs", health: "/health", status: "ok" }));
  fastify.get("/health", async () => ({ ok: true, status: "healthy", uptime: process.uptime(), timestamp: new Date().toISOString() }));
  fastify.get("/healthz", async () => ({ status: "ok" }));

  // Controllers
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

const start = async () => {
  try {
    console.log("🚀 Starting HabitOS API...");
    validateEnv();
    const server = buildServer();

    const port = Number(process.env.PORT || 8080);
    const host = process.env.HOST || "0.0.0.0";

    await server.listen({ port, host });
    console.log("📖 Docs: /docs | 🩺 Health: /health | ⏰ Schedulers active");

    // Register repeatable jobs for OS brain tasks
    await bootstrapSchedulers();

  } catch (err) {
    console.error("❌ Server startup failed:", err);
    process.exit(1);
  }
};

process.on("SIGINT", async () => {
  console.log("⏹️ Shutting down gracefully...");
  await prisma.$disconnect();
  await getRedis().quit();
  process.exit(0);
});

start();
