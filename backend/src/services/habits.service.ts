// src/services/habits.service.ts
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';

type Schedule =
  | { type: 'daily'; time?: string }
  | { type: 'weekdays'; time?: string }             // Mon–Fri
  | { type: 'custom'; days: number[]; time?: string } // days: 0=Sun..6=Sat
  | Record<string, unknown>;

function startOfDayISO(d: Date) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x.toISOString();
}
function ymd(d: Date) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  const y = x.getFullYear();
  const m = `${x.getMonth() + 1}`.padStart(2, '0');
  const dd = `${x.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${dd}`;
}
function daysBetween(a: Date, b: Date) {
  const ms = startOfDayISO(b) > startOfDayISO(a)
    ? new Date(startOfDayISO(b)).getTime() - new Date(startOfDayISO(a)).getTime()
    : new Date(startOfDayISO(a)).getTime() - new Date(startOfDayISO(b)).getTime();
  return Math.round(ms / (24 * 60 * 60 * 1000));
}

export class HabitsService {
  /**
   * List habits for a user with derived "status" for today.
   */
  async list(userId: string) {
    const habits = await prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    const todayStr = new Date().toDateString();

    return habits.map((h) => {
      const lastTickToday =
        h.lastTick && new Date(h.lastTick).toDateString() === todayStr;
      return {
        id: h.id,
        userId: h.userId,
        title: h.title,
        streak: h.streak,
        lastTick: h.lastTick,
        schedule: (h.schedule as unknown as Schedule) ?? {},
        createdAt: h.createdAt,
        updatedAt: h.updatedAt,
        status: lastTickToday ? 'completed_today' : 'pending',
      };
    });
  }

  /**
   * Create a new habit.
   * `data` may include: title (required), schedule (optional)
   */
  async create(userId: string, data: { title: string; schedule?: Schedule }) {
    if (!data?.title || !data.title.trim()) {
      throw new Error('Title is required');
    }

    const habit = await prisma.habit.create({
      data: {
        userId,
        title: data.title.trim(),
        schedule: data.schedule ?? { type: 'daily' },
        streak: 0,
        lastTick: null,
      },
    });

    await prisma.event.create({
      data: {
        userId,
        type: 'habit_created',
        payload: { habitId: habit.id, title: habit.title },
      },
    });

    return habit;
  }

  /**
   * Update habit (title, schedule).
   */
  async update(
    id: string,
    userId: string,
    updateData: Partial<{ title: string; schedule: Schedule }>,
  ) {
    const existing = await prisma.habit.findFirst({ where: { id, userId } });
    if (!existing) throw new Error('Habit not found');

    const updated = await prisma.habit.update({
      where: { id },
      data: {
        title:
          typeof updateData.title === 'string'
            ? updateData.title
            : existing.title,
        schedule:
          typeof updateData.schedule !== 'undefined'
            ? updateData.schedule
            : existing.schedule,
      },
    });

    await prisma.event.create({
      data: {
        userId,
        type: 'habit_updated',
        payload: { habitId: id, changes: updateData },
      },
    });

    return updated;
  }

  /**
   * Delete habit.
   */
  async delete(id: string, userId: string) {
    const existing = await prisma.habit.findFirst({ where: { id, userId } });
    if (!existing) throw new Error('Habit not found');

    const deleted = await prisma.habit.delete({ where: { id } });

    await prisma.event.create({
      data: {
        userId,
        type: 'habit_deleted',
        payload: { habitId: id, title: existing.title },
      },
    });

    return { ok: true, deleted };
  }

  /**
   * Tick habit for "today" (idempotent per user+habit+day).
   * - If already ticked today: returns idempotent=true
   * - If lastTick is yesterday: streak += 1
   * - If lastTick is older: streak = 1
   */
  async tick(id: string, userId: string, idempotencyKey?: string) {
    const habit = await prisma.habit.findFirst({ where: { id, userId } });
    if (!habit) throw new Error('Habit not found');

    const today = new Date();
    const todayStr = today.toDateString();
    const dateKey = ymd(today);

    // Secondary protection: idempotency via Redis (per day)
    const idemKey =
      idempotencyKey ||
      `habit:tick:${userId}:${id}:${dateKey}`; // user+habit+day
    const existed = await redis.get(idemKey);
    if (existed) {
      // Already processed today
      return {
        ok: true,
        idempotent: true,
        streak: habit.streak,
        timestamp: habit.lastTick,
        message: 'Habit already completed today',
      };
    }

    // Also check DB "already ticked today"
    const alreadyTickedToday =
      habit.lastTick &&
      new Date(habit.lastTick).toDateString() === todayStr;

    if (alreadyTickedToday) {
      // Set idempotency marker for 36h to cover TZ drift.
      await redis.set(idemKey, '1', 'EX', 36 * 60 * 60);
      return {
        ok: true,
        idempotent: true,
        streak: habit.streak,
        timestamp: habit.lastTick,
        message: 'Habit already completed today',
      };
    }

    // Compute new streak
    let newStreak = 1;
    if (habit.lastTick) {
      const gap = daysBetween(new Date(habit.lastTick), today);
      if (gap === 1) newStreak = habit.streak + 1;
      else if (gap === 0) newStreak = habit.streak; // safety
      else newStreak = 1; // gap > 1 resets
    }

    const updated = await prisma.habit.update({
      where: { id },
      data: {
        lastTick: today,
        streak: newStreak,
      },
    });

    // Log event + milestone detection
    const milestones = [7, 14, 30, 60, 90, 180, 365];
    const achievedMilestone = milestones.find(
      (m) => newStreak === m,
    );

    await prisma.event.create({
      data: {
        userId,
        type: 'habit_tick',
        payload: {
          habitId: id,
          title: habit.title,
          previousStreak: habit.streak,
          streak: newStreak,
          achievedMilestone: achievedMilestone ?? null,
        },
      },
    });

    // mark idempotent for rest of the day
    await redis.set(idemKey, '1', 'EX', 36 * 60 * 60);

    return {
      ok: true,
      idempotent: false,
      streak: newStreak,
      timestamp: updated.lastTick,
      achievedMilestone: achievedMilestone ?? null,
      message: `Habit ticked. Streak: ${newStreak}`,
    };
  }
}

export const habitsService = new HabitsService();
