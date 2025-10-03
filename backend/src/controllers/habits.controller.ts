import { FastifyInstance } from "fastify";
import { HabitsService } from "../services/habits.service";
import { prisma } from "../utils/db";

export async function habitsController(fastify: FastifyInstance) {
  const service = new HabitsService();

  // Helper to ensure demo user exists before operations
  async function ensureDemoUser(userId: string) {
    if (userId === "demo-user-123") {
      const existingUser = await prisma.user.findUnique({ where: { id: userId } });
      if (!existingUser) {
        await prisma.user.create({
          data: {
            id: userId,
            email: "demo@drillsergeant.com",
            tz: "Europe/London",
            tone: "balanced",
            intensity: 2,
            consentRoast: false,
            plan: "FREE",
            mentorId: "marcus",
            nudgesEnabled: true,
            briefsEnabled: true,
            debriefsEnabled: true,
          },
        });
        console.log("✅ Created demo user:", userId);
      }
    }
  }

  // List habits (with "completed today" status)
  fastify.get("/api/v1/habits", async (req, reply) => {
    const userId = (req as any).user?.id || req.headers['x-user-id'] || "demo-user-123";
    await ensureDemoUser(userId);
    const habits = await service.list(userId);
    return habits;
  });

  // Create habit
  fastify.post("/api/v1/habits", async (req, reply) => {
    try {
      const userId = (req as any).user?.id || req.headers['x-user-id'] || "demo-user-123";
      await ensureDemoUser(userId);
      const body = req.body as any;

      const habit = await service.create(userId, {
        title: body.title ?? body.name,
        schedule: body.schedule ?? scheduleFromForm(body),
        color: body.color ?? null,
        context: {
          difficulty: body.difficulty ?? body.intensity ?? 2,
          category: body.category ?? "general",
          lifeDays: 0,
        },
        reminderEnabled: body.reminderEnabled ?? body.reminderOn ?? false,
        reminderTime: body.reminderTime ?? "08:00",
      });

      // Auto-select the new habit for today's brief
      try {
        const { todayService } = await import('../services/today.service');
        await todayService.selectForToday(userId, habit.id, undefined);
      } catch (e) {
        console.warn('⚠️ Failed to auto-select habit for today:', e);
      }

      reply.code(201);
      return habit;
    } catch (e: any) {
      console.error('❌ Error creating habit:', e);
      reply.code(400);
      return { error: e.message };
    }
  });

  // Tick habit (idempotent per date)
  fastify.post<{
    Params: { id: string };
    Body: { date?: string };
    Headers: { "idempotency-key"?: string } & Record<string, string>;
  }>("/api/v1/habits/:id/tick", async (req, reply) => {
    const userId = (req as any).user?.id || req.headers['x-user-id'] || "demo-user-123";
    const id = req.params.id;
    const body = req.body || {};
    const dateStr = (body as any).date; // optional ISO YYYY-MM-DD
    const idempotencyKey = (req.headers["idempotency-key"] ||
      req.headers["Idempotency-Key"] ||
      req.headers["IDEMPOTENCY-KEY"]) as string | undefined;

    const res = await service.tick({
      habitId: id,
      userId,
      dateISO: dateStr,
      idempotencyKey,
    });

    return res;
  });

  // Delete habit
  fastify.delete<{
    Params: { id: string };
  }>("/api/v1/habits/:id", async (req, reply) => {
    try {
      const userId = (req as any).user?.id || req.headers['x-user-id'] || "demo-user-123";
      await ensureDemoUser(userId);
      const id = req.params.id;
      const res = await service.delete(id, userId);
      reply.code(200);
      return res;
    } catch (e: any) {
      reply.code(400);
      return { error: e.message };
    }
  });
}

// helpers
function scheduleFromForm(body: any) {
  // Accepts the UI format you already use
  // e.g. frequency: 'daily' | 'weekdays' | 'everyN', everyN: number, startDate/endDate
  const schedule: any = { type: body.frequency ?? "daily" };
  if (schedule.type === "everyN" && body.everyN) schedule.everyN = Number(body.everyN);
  if (body.startDate) schedule.startDate = body.startDate;
  if (body.endDate) schedule.endDate = body.endDate;
  return schedule;
}
