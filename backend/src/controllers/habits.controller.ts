import { FastifyInstance } from "fastify";
import { habitsService } from "../services/habits.service";
import { prisma } from "../utils/db";

export async function habitsController(fastify: FastifyInstance) {
  // 🧠 Ensure demo user exists (for local/testing mode)
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
            plan: "FREE",
          },
        });
        console.log("✅ Created demo user:", userId);
      }
    }
  }

  // ✅ GET habits
  fastify.get("/api/v1/habits", async (req, reply) => {
    const userId = (req as any).user?.id || req.headers["x-user-id"] || "demo-user-123";
    await ensureDemoUser(userId);
    const habits = await habitsService.list(userId);
    reply.send(habits);
  });

  // ✅ CREATE habit
  fastify.post("/api/v1/habits", async (req, reply) => {
    try {
      const userId = (req as any).user?.id || req.headers["x-user-id"] || "demo-user-123";
      await ensureDemoUser(userId);
      const habit = await habitsService.create(userId, req.body as any);
      reply.code(201).send(habit);
    } catch (e: any) {
      console.error("❌ Error creating habit:", e);
      reply.code(400).send({ error: e.message });
    }
  });

  // ✅ TICK habit (mark complete)
  fastify.post("/api/v1/habits/:id/tick", async (req, reply) => {
    const userId = (req as any).user?.id || req.headers["x-user-id"] || "demo-user-123";
    const id = req.params["id"];
    const date = (req.body as any)?.date;
    const idempotencyKey =
      (req.headers["idempotency-key"] as string) ||
      (req.headers["Idempotency-Key"] as string) ||
      undefined;

    const result = await habitsService.tick({
      habitId: id,
      userId,
      dateISO: date,
      idempotencyKey,
    });

    reply.send(result);
  });

  // ✅ DELETE habit (fix for "Body cannot be empty" bug)
  fastify.delete("/api/v1/habits/:id", async (req, reply) => {
    try {
      const userId = (req as any).user?.id || req.headers["x-user-id"] || "demo-user-123";
      const id = req.params["id"];
      await ensureDemoUser(userId);

      // 🔥 PATCH: allow empty JSON bodies from Flutter
      if (req.headers["content-type"]?.includes("application/json") && !req.body) {
        req.body = {};
      }

      const result = await habitsService.delete(id, userId);
      reply.code(200).send(result);
    } catch (e: any) {
      console.error("❌ Error deleting habit:", e);
      reply.code(400).send({ error: e.message });
    }
  });
}
