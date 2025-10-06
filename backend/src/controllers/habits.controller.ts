import { FastifyInstance } from "fastify";
import { habitsService } from "../services/habits.service";
import { prisma } from "../utils/db";

export async function habitsController(fastify: FastifyInstance) {
  async function ensureDemoUser(userId: string) {
    if (userId === "demo-user-123") {
      const exists = await prisma.user.findUnique({ where: { id: userId } });
      if (!exists) {
        await prisma.user.create({
          data: {
            id: userId,
            email: "demo@drillsergeant.com",
            mentorId: "marcus",
            tone: "balanced",
            intensity: 2,
            plan: "FREE"
          }
        });
      }
    }
  }

  fastify.get("/api/v1/habits", async (req) => {
    const userId = (req as any).user?.id || (req.headers["x-user-id"] as string) || "demo-user-123";
    await ensureDemoUser(userId);
    return habitsService.list(userId);
  });

  fastify.post("/api/v1/habits", async (req, reply) => {
    const userId = (req as any).user?.id || (req.headers["x-user-id"] as string) || "demo-user-123";
    await ensureDemoUser(userId);
    const created = await habitsService.create(userId, req.body as any);
    reply.code(201).send(created);
  });

  fastify.put("/api/v1/habits/:id", async (req, reply) => {
    const userId = (req as any).user?.id || (req.headers["x-user-id"] as string) || "demo-user-123";
    const id = (req.params as any).id;
    const updated = await habitsService.update(userId, id, req.body as any);
    reply.send(updated);
  });

  fastify.delete("/api/v1/habits/:id", async (req, reply) => {
    const userId = (req as any).user?.id || (req.headers["x-user-id"] as string) || "demo-user-123";
    const id = (req.params as any).id;
    const result = await habitsService.remove(userId, id);
    reply.send(result);
  });

  fastify.post("/api/v1/habits/:id/tick", async (req) => {
    const userId = (req as any).user?.id || (req.headers["x-user-id"] as string) || "demo-user-123";
    const id = (req.params as any).id;
    const date = (req.body as any)?.date;
    return habitsService.tick(userId, id, date);
  });
}
