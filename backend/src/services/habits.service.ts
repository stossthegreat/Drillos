import { prisma } from "../utils/db";
import { todayService } from "./today.service";

type CreateHabitInput = {
  title: string;
  schedule: {
    type: "daily" | "weekdays" | "everyN" | "custom";
    everyN?: number;
    startDate?: string;
    endDate?: string;
  };
  color?: string | null;
  context?: any;
  reminderEnabled?: boolean;
  reminderTime?: string | null;
};

type TickInput = {
  habitId: string;
  userId: string;
  dateISO?: string;
  idempotencyKey?: string;
};

export class HabitsService {
  async list(userId: string) {
    const habits = await prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: "asc" },
    });
    const todayKey = new Date().toISOString().split("T")[0];
    return habits.map((h) => ({
      ...h,
      completedToday:
        h.lastTick &&
        new Date(h.lastTick).toISOString().split("T")[0] === todayKey,
    }));
  }

  async getById(id: string, userId: string) {
    return prisma.habit.findFirst({ where: { id, userId } });
  }

  async create(userId: string, input: CreateHabitInput) {
    const habit = await prisma.habit.create({
      data: {
        title: input.title,
        schedule: input.schedule ?? { type: "daily" },
        color: input.color ?? "emerald",
        streak: 0,
        lastTick: null,
        context: input.context ?? {},
        reminderEnabled: input.reminderEnabled ?? false,
        reminderTime: input.reminderTime ?? null,
        user: { connect: { id: userId } },
      },
    });

    await this.logEvent(userId, "habit_created", {
      habitId: habit.id,
      title: habit.title,
    });

    // Auto-select for today only if schedule matches
    const shouldSelectToday = this.isScheduledToday(habit.schedule);
    if (shouldSelectToday) {
      try {
        await todayService.selectForToday(userId, habit.id, undefined);
      } catch (e) {
        console.warn("⚠️ Auto-select skipped:", e);
      }
    }

    return habit;
  }

  async delete(id: string, userId: string) {
    const habit = await prisma.habit.findFirst({ where: { id, userId } });
    if (!habit) return { ok: false, error: "Habit not found" };

    await prisma.$transaction([
      prisma.todaySelection.deleteMany({ where: { userId, habitId: id } }),
      prisma.habit.delete({ where: { id } }),
    ]);

    await this.logEvent(userId, "habit_deleted", {
      habitId: id,
      title: habit.title,
    });

    return { ok: true };
  }

  async tick({ habitId, userId, dateISO, idempotencyKey }: TickInput) {
    const habit = await prisma.habit.findFirst({ where: { id: habitId, userId } });
    if (!habit) return { ok: false, message: "Habit not found" };

    const date = dateISO ? new Date(`${dateISO}T00:00:00Z`) : new Date();
    const dateKey = date.toISOString().split("T")[0];

    const existing = await prisma.event.findFirst({
      where: {
        userId,
        type: "habit_tick",
        payload: { path: ["habitId"], equals: habitId } as any,
        ts: {
          gte: new Date(`${dateKey}T00:00:00.000Z`),
          lt: new Date(`${dateKey}T23:59:59.999Z`),
        },
      },
    });
    if (existing) return { ok: true, idempotent: true };

    const lastTick = habit.lastTick ? new Date(habit.lastTick) : null;
    const wasYesterday =
      lastTick && this.dayKey(lastTick) === this.dayKey(this.addDays(date, -1));
    const newStreak = wasYesterday ? habit.streak + 1 : 1;

    await prisma.habit.update({
      where: { id: habitId },
      data: { lastTick: date, streak: newStreak },
    });

    await this.logEvent(userId, "habit_tick", {
      habitId,
      date: dateKey,
      newStreak,
      idempotencyKey,
    });

    return { ok: true, streak: newStreak, completedOn: dateKey };
  }

  private async logEvent(userId: string, type: string, payload: any) {
    await prisma.event.create({ data: { userId, type, payload } });
  }

  private isScheduledToday(schedule: any): boolean {
    if (!schedule || !schedule.type) return true;
    const today = new Date();
    const day = today.getDay(); // 0=Sun...6=Sat
    const dateKey = today.toISOString().split("T")[0];

    switch (schedule.type) {
      case "daily":
        return true;
      case "weekdays":
        return day >= 1 && day <= 5;
      case "everyN":
        if (!schedule.startDate || !schedule.everyN) return true;
        const start = new Date(schedule.startDate);
        const diff =
          Math.floor(
            (today.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
          ) % schedule.everyN;
        return diff === 0;
      case "custom":
        if (schedule.startDate && today < new Date(schedule.startDate)) return false;
        if (schedule.endDate && today > new Date(schedule.endDate)) return false;
        return true;
      default:
        return true;
    }
  }

  private dayKey(d: Date) {
    return d.toISOString().split("T")[0];
  }
  private addDays(d: Date, n: number) {
    const x = new Date(d);
    x.setUTCDate(x.getUTCDate() + n);
    return x;
  }
}

export const habitsService = new HabitsService();
