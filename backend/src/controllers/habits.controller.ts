import { FastifyInstance } from "fastify";
import { HabitsService } from "../services/habits.service";

export async function habitsController(fastify: FastifyInstance) {
  const service = new HabitsService();

  // List habits (with “completed today” status)
  fastify.get("/api/v1/habits", async (req, reply) => {
    // TODO: replace with real auth userId
    const userId = (req as any).user?.id || "demo-user-123";
    const habits = await service.list(userId);
    return habits;
  });

  // Create habit
  fastify.post("/api/v1/habits", async (req, reply) => {
    const userId = (req as any).user?.id || "demo-user-123";
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

    reply.code(201);
    return habit;
  });

  // Tick habit (idempotent per date)
  fastify.post<{
    Params: { id: string };
    Body: { date?: string };
    Headers: { "idempotency-key"?: string } & Record<string, string>;
  }>("/api/v1/habits/:id/tick", async (req, reply) => {
    const userId = (req as any).user?.id || "demo-user-123";
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
    const userId = (req as any).user?.id || "demo-user-123";
    const id = req.params.id;
    const res = await service.delete(id, userId);
    return res;
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
