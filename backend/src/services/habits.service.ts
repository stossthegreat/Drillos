import { prisma } from "../utils/db";

type CreateHabitInput = {
  title: string;
  schedule: any;
  color?: string | null;
  context?: any;
  reminderEnabled?: boolean;
  reminderTime?: string | null;
};

type TickInput = {
  habitId: string;
  userId: string;
  dateISO?: string;        // optional YYYY-MM-DD
  idempotencyKey?: string; // optional
};

export class HabitsService {
  async list(userId: string) {
    const habits = await prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: "asc" },
    });

    const today = new Date().toDateString();

    return habits.map((h) => ({
      ...h,
      status:
        h.lastTick && new Date(h.lastTick).toDateString() === today
          ? "completed_today"
          : "pending",
    }));
  }

  async getById(id: string, userId: string) {
    const habit = await prisma.habit.findFirst({
      where: { id, userId },
    });
    return habit;
  }

  async create(userId: string, input: CreateHabitInput) {
    const habit = await prisma.habit.create({
      data: {
        userId,
        title: input.title,
        schedule: input.schedule ?? {},
        streak: 0,
        lastTick: null,
        color: input.color,
        context: input.context ?? {},
        reminderEnabled: input.reminderEnabled ?? false,
        reminderTime: input.reminderTime ?? null,
      },
    });
    await this.logEvent(userId, "habit_created", { habitId: habit.id, title: habit.title });
    return habit;
  }

  async delete(id: string, userId: string) {
    const habit = await prisma.habit.findFirst({ where: { id, userId } });
    if (!habit) {
      return { ok: false, error: "Habit not found" };
    }
    await prisma.habit.delete({ where: { id } });
    await this.logEvent(userId, "habit_deleted", { habitId: id, title: habit.title });
    return { ok: true, deleted: { id, title: habit.title, streak: habit.streak } };
  }

  async tick({ habitId, userId, dateISO, idempotencyKey }: TickInput) {
    const habit = await prisma.habit.findFirst({ where: { id: habitId, userId } });
    if (!habit) return { ok: false, message: "Habit not found" };

    const date = dateISO ? new Date(`${dateISO}T00:00:00Z`) : new Date();
    const dateKey = date.toISOString().split("T")[0];

    // Check duplicate (idempotency)
    const existing = await prisma.event.findFirst({
      where: {
        userId,
        type: "habit_tick",
        ts: {
          gte: new Date(`${dateKey}T00:00:00.000Z`),
          lt: new Date(`${dateKey}T23:59:59.999Z`),
        },
        payload: {
          path: ["habitId"],
          equals: habitId,
        } as any,
      },
    });

    if (existing) {
      return {
        ok: true,
        idempotent: true,
        message: "Already completed today",
        streak: habit.streak,
        timestamp: habit.lastTick,
      };
    }

    // streak calc
    const lastTick = habit.lastTick ? new Date(habit.lastTick) : null;
    const wasYesterday = lastTick && dayKey(lastTick) === dayKey(addDays(date, -1));
    const nextStreak = !lastTick ? 1 : wasYesterday ? habit.streak + 1 : 1;

    const updated = await prisma.habit.update({
      where: { id: habitId },
      data: { streak: nextStreak, lastTick: date },
    });

    await this.logEvent(userId, "habit_tick", {
      habitId,
      title: habit.title,
      date: dateKey,
      nextStreak,
      idempotencyKey: idempotencyKey ?? null,
    });

    return {
      ok: true,
      idempotent: false,
      message: `Completed on ${dateKey}`,
      streak: nextStreak,
      timestamp: date.toISOString(),
    };
  }

  private async logEvent(userId: string, type: string, payload: any) {
    return prisma.event.create({
      data: { userId, type, payload },
    });
  }
}

function dayKey(d: Date) {
  return d.toISOString().split("T")[0];
}
function addDays(d: Date, n: number) {
  const x = new Date(d);
  x.setUTCDate(x.getUTCDate() + n);
  return x;
}
