import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

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
      id: h.id,
      userId: h.userId,
      title: h.title,
      streak: h.streak,
      schedule: h.schedule,
      lastTick: h.lastTick,
      color: (h as any).color ?? null, // if you added color column later, map it here
      reminderEnabled: (h as any).reminderEnabled ?? false,
      reminderTime: (h as any).reminderTime ?? null,
      createdAt: h.createdAt,
      status:
        h.lastTick && new Date(h.lastTick).toDateString() === today
          ? "completed_today"
          : "pending",
    }));
  }

  async create(userId: string, input: CreateHabitInput) {
    const habit = await prisma.habit.create({
      data: {
        userId,
        title: input.title,
        schedule: input.schedule ?? {},
        streak: 0,
        lastTick: null,
        // If you have extra columns (color, reminderEnabled, reminderTime) add them to Prisma first.
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

  /**
   * Idempotent tick per day:
   * - If already ticked for the date, returns idempotent: true
   * - If not, increments streak (with break check) and sets lastTick
   */
  async tick({ habitId, userId, dateISO, idempotencyKey }: TickInput) {
    const habit = await prisma.habit.findFirst({ where: { id: habitId, userId } });
    if (!habit) return { ok: false, message: "Habit not found" };

    const date = dateISO ? new Date(`${dateISO}T00:00:00Z`) : new Date();
    const dateKey = date.toISOString().split("T")[0]; // YYYY-MM-DD

    // Check if we already logged a tick event for the same date
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
        message: "Habit already completed for this date",
        streak: habit.streak,
        timestamp: habit.lastTick,
      };
    }

    // Compute streak change:
    // If lastTick was yesterday (or today), continue streak; if missed a day, reset to 1.
    const nowUTC = new Date();
    const lastTick = habit.lastTick ? new Date(habit.lastTick) : null;

    const isSameDay =
      lastTick && lastTick.toDateString() === date.toDateString();
    const wasYesterday =
      lastTick &&
      dayKey(lastTick) === dayKey(addDays(date, -1));

    let nextStreak: number;
    if (!lastTick) nextStreak = 1;
    else if (isSameDay) nextStreak = habit.streak; // should not happen due to existing event check, but safe
    else if (wasYesterday) nextStreak = habit.streak + 1;
    else nextStreak = 1; // break

    // Update habit
    const updated = await prisma.habit.update({
      where: { id: habitId },
      data: {
        streak: nextStreak,
        lastTick: date, // store the tick date
      },
    });

    // Log event
    const ev = await this.logEvent(userId, "habit_tick", {
      habitId,
      title: habit.title,
      date: dateKey,
      nextStreak,
      idempotencyKey: idempotencyKey ?? null,
    });

    // milestone examples
    const milestones = [7, 14, 30, 60, 90, 180, 365];
    const achievedMilestone = milestones.includes(nextStreak) ? nextStreak : null;

    return {
      ok: true,
      idempotent: false,
      message: `Habit completed for ${dateKey}.`,
      streak: nextStreak,
      achievedMilestone,
      eventId: ev.id,
      timestamp: date.toISOString(),
    };
  }

  private async logEvent(userId: string, type: string, payload: any) {
    return prisma.event.create({
      data: {
        userId,
        type,
        payload,
      },
    });
  }
}

// helpers
function dayKey(d: Date) {
  return d.toISOString().split("T")[0];
}
function addDays(d: Date, n: number) {
  const x = new Date(d);
  x.setUTCDate(x.getUTCDate() + n);
  return x;
        }
