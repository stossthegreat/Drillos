import { FastifyInstance } from "fastify";
import { notificationsService } from "../services/notifications.service";

export async function notificationsController(fastify: FastifyInstance) {
  // Send notification immediately
  fastify.post("/api/v1/notifications/send", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { title, body } = req.body as { title: string; body: string };
      return await notificationsService.send(userId, title, body);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // Schedule delayed notification
  fastify.post("/api/v1/notifications/schedule", async (req: any, reply) => {
    try {
      const userId = req.user?.id || req.headers["x-user-id"];
      if (!userId) return reply.code(401).send({ error: "Unauthorized" });

      const { title, body, delaySeconds } = req.body as {
        title: string;
        body: string;
        delaySeconds: number;
      };

      return await notificationsService.schedule(userId, title, body, delaySeconds);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
