import Fastify from "fastify";
import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import { userController } from "./controllers/user.controller";

async function buildServer() {
  const fastify = Fastify({ logger: true });

  // Middleware
  await fastify.register(cors, { origin: true });

  // Swagger documentation
  await fastify.register(swagger, {
    openapi: {
      openapi: "3.0.0",
      info: {
        title: "DrillSergeant OS API",
        version: "1.0.0",
        description: "The Active OS with mentors, habits, alarms, nudges, and memory.",
      },
      servers: [{ url: "http://localhost:8080" }],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
          },
        },
      },
    },
  });

  await fastify.register(swaggerUi, {
    routePrefix: "/docs",
    uiConfig: { docExpansion: "list", deepLinking: true },
  });

  // Health check
  fastify.get("/health", async () => {
    return { ok: true, message: "🔥 DrillSergeant OS backend is running." };
  });

  // Controllers
  fastify.register(userController);

  return fastify;
}

async function start() {
  try {
    const server = await buildServer();
    const port = process.env.PORT ? Number(process.env.PORT) : 8080;
    const host = process.env.HOST || "0.0.0.0";

    await server.listen({ port, host });
    console.log(`🚀 Server running at http://${host}:${port}`);
    console.log(`📖 API docs available at http://${host}:${port}/docs`);
  } catch (err) {
    console.error("❌ Failed to start server:", err);
    process.exit(1);
  }
}

start();
