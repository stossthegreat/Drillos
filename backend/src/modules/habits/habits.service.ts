import { PrismaClient } from '@prisma/client';
import IORedis from 'ioredis';
import { RRule, RRuleSet, rrulestr } from 'rrule';

// ---- Types for schedule JSON stored in Habit.schedule ----
type DaysAbbr =
  | 'sun' | 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat';

type ScheduleJson =
  | { type: 'daily'; time?: string }
  | { type: 'weekdays'; time?: string }
  | { type: 'weekends'; time?: string }
  | { type: 'daysOfWeek'; days: DaysAbbr[]; time?: string }
  | { type: 'everyN'; every: number; startDate: string; time?: string } // every N days from startDate
  | { type: 'rrule'; rule: string; time?: string }; // RFC 5545 RRULE (e.g., FREQ=DAILY;INTERVAL=2)

export interface CreateHabitInput {
  userId: string;
  title: string;
  schedule: ScheduleJson;
  color?: string;
  context?: Record<string, unknown>;
  reminderEnabled?: boolean;
  reminderTime?: string; // "HH:mm"
}

export interface UpdateHabitInput {
  title?: string;
  schedule?: ScheduleJson;
  color?: string;
  context?: Record<string, unknown>;
  reminderEnabled?: boolean;
  reminderTime?: string;
}

export interface TickResult {
  ok: boolean;
  idempotent: boolean;
  streak: number;
  timestamp: string; // ISO
  message: string;
}

export class HabitsService {
  private prisma: PrismaClient;
  private redis: IORedis;

  constructor(opts?: { prisma?: PrismaClient; redis?: IORedis }) {
    this.prisma = opts?.prisma ?? new PrismaClient();
    this.redis = opts?.redis ?? new IORedis(process.env.REDIS_URL || 'redis://localhost:6379');
  }

  // ---------- Public API ----------

  async list(userId: string, forDateISO?: string): Promise<(any & { status: 'pending' | 'completed_today' })[]> {
    const date = forDateISO ? new Date(forDateISO) : new Date();
    const user = await this.mustGetUser(userId);

    const habits = await this.prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    const todayKey = this.localDayKey(date, user.tz);
    return habits.map((h: any) => {
      const last = h.lastTick ? this.localDayKey(new Date(h.lastTick), user.tz) : null;
      const completedToday = last === todayKey;
      return {
        ...h,
        status: completedToday ? 'completed_today' : 'pending',
      };
    }).filter((h: any) => this.isScheduledForDate(this.asSchedule(h.schedule), date, user.tz));
  }

  async create(input: CreateHabitInput): Promise<any> {
    const user = await this.mustGetUser(input.userId);

    const schedule = this.normalizeSchedule(input.schedule);
    const habit = await this.prisma.habit.create({
      data: {
        userId: input.userId,
        title: input.title,
        schedule,
        streak: 0,
        lastTick: null,
        color: input.color ?? 'emerald',
        context: input.context ?? {},
        // Optional extras if your schema has them (reminderEnabled, reminderTime)
        // @ts-ignore - ignore if fields don't exist in your schema
        reminderEnabled: input.reminderEnabled ?? false,
        // @ts-ignore
        reminderTime: input.reminderTime ?? '08:00',
      },
    });

    // optional: emit event
    await this.logEvent(user.id, 'habit_created', { habitId: habit.id, title: habit.title });

    return habit;
  }

  async update(habitId: string, userId: string, updates: UpdateHabitInput): Promise<any> {
    await this.mustOwnHabit(habitId, userId);

    const data: any = { ...updates };
    if (updates.schedule) {
      data.schedule = this.normalizeSchedule(updates.schedule);
    }

    const updated = await this.prisma.habit.update({
      where: { id: habitId },
      data,
    });

    await this.logEvent(userId, 'habit_updated', { habitId, updates: data });
    return updated;
  }

  async delete(habitId: string, userId: string): Promise<{ ok: boolean; deleted: any }> {
    await this.mustOwnHabit(habitId, userId);

    const deleted = await this.prisma.habit.delete({
      where: { id: habitId },
    });
    await this.logEvent(userId, 'habit_deleted', { habitId, title: deleted.title });
    return { ok: true, deleted };
  }

  /**
   * Idempotent tick.
   * - If already ticked today (user tz), returns idempotent=true.
   * - Otherwise, updates lastTick & streak with reset if gap was > 1 local day.
   * - Uses Redis to lock by (userId:habitId:YYYY-MM-DD) to prevent double-ticking races.
   */
  async tick(habitId: string, userId: string, opts?: { idempotencyKey?: string; dateISO?: string }): Promise<TickResult> {
    const user = await this.mustGetUser(userId);
    const habit = await this.mustOwnHabit(habitId, userId);

    const now = opts?.dateISO ? new Date(opts.dateISO) : new Date();
    const todayKey = this.localDayKey(now, user.tz);

    // Optional: enforce schedule (only allow ticking on scheduled day)
    const schedule = this.asSchedule(habit.schedule);
    const isSched = this.isScheduledForDate(schedule, now, user.tz);
    if (!isSched) {
      return {
        ok: false,
        idempotent: true,
        streak: habit.streak,
        timestamp: habit.lastTick ? new Date(habit.lastTick).toISOString() : new Date().toISOString(),
        message: 'Not scheduled for today',
      };
    }

    // Redis idempotency lock for this day
    const idemKey = this.buildIdemKey(userId, habitId, todayKey, opts?.idempotencyKey);
    const gotLock = await this.tryAcquireIdem(idemKey);
    if (!gotLock) {
      // Another identical tick in flight OR already processed
      const h2 = await this.prisma.habit.findUnique({ where: { id: habitId } });
      return {
        ok: true,
        idempotent: true,
        streak: h2?.streak ?? habit.streak,
        timestamp: h2?.lastTick ? new Date(h2.lastTick).toISOString() : new Date().toISOString(),
        message: 'Already completed today',
      };
    }

    // Already ticked today?
    const lastKey = habit.lastTick ? this.localDayKey(new Date(habit.lastTick), user.tz) : null;
    if (lastKey === todayKey) {
      return {
        ok: true,
        idempotent: true,
        streak: habit.streak,
        timestamp: new Date(habit.lastTick!).toISOString(),
        message: 'Already completed today',
      };
    }

    // Compute next streak
    const newStreak = this.computeNextStreak(habit, now, user.tz);

    const updated = await this.prisma.habit.update({
      where: { id: habitId },
      data: {
        lastTick: now,
        streak: newStreak,
      },
    });

    await this.logEvent(userId, 'habit_tick', {
      habitId,
      title: habit.title,
      previousStreak: habit.streak,
      streak: updated.streak,
      localDay: todayKey,
    });

    return {
      ok: true,
      idempotent: false,
      streak: updated.streak,
      timestamp: updated.lastTick!.toISOString(),
      message: `Completed! Streak: ${updated.streak}`,
    };
  }

  // ---------- Helpers ----------

  private async mustGetUser(userId: string): Promise<any> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error('User not found');
    return user;
  }

  private async mustOwnHabit(habitId: string, userId: string): Promise<any> {
    const habit = await this.prisma.habit.findUnique({ where: { id: habitId } });
    if (!habit || habit.userId !== userId) {
      throw new Error('Habit not found');
    }
    return habit;
  }

  private asSchedule(raw: any): ScheduleJson {
    // If schedule is stored as JSON in DB, it may already be parsed by Prisma.
    // Accept strings or objects defensively.
    if (!raw) return { type: 'daily' };
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch {
        // fallback
        return { type: 'daily' };
      }
    }
    return raw as ScheduleJson;
  }

  private normalizeSchedule(s: ScheduleJson): ScheduleJson {
    // Basic validation/normalization before writing to DB
    switch (s.type) {
      case 'daily':
      case 'weekdays':
      case 'weekends':
        return s;
      case 'daysOfWeek': {
        const valid: DaysAbbr[] = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
        const days = (s.days || []).filter((d): d is DaysAbbr => {
          return typeof d === 'string' && valid.includes(d as DaysAbbr);
        });
        return { ...s, days: Array.from(new Set(days)) };
      }
      case 'everyN': {
        const every = Math.max(1, Math.floor(Number(s.every || 1)));
        const startDate = s.startDate && !isNaN(Date.parse(s.startDate)) ? s.startDate : new Date().toISOString().slice(0, 10);
        return { ...s, every, startDate };
      }
      case 'rrule': {
        // Validate RRULE string
        try { rrulestr(`RRULE:${s.rule}`); } catch { throw new Error('Invalid RRULE'); }
        return s;
      }
      default:
        return { type: 'daily' };
    }
  }

  private isScheduledForDate(s: ScheduleJson, date: Date, tz: string): boolean {
    const d = this.zoned(date, tz);
    const dow = d.getDay(); // 0=Sun...6=Sat

    switch (s.type) {
      case 'daily':
        return true;

      case 'weekdays':
        return dow >= 1 && dow <= 5;

      case 'weekends':
        return dow === 0 || dow === 6;

      case 'daysOfWeek': {
        const map: DaysAbbr[] = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
        const dayAbbr = map[dow];
        return dayAbbr ? (s.days || []).includes(dayAbbr) : false;
      }

      case 'everyN': {
        const start = this.startOfLocalDay(new Date(s.startDate), tz);
        const target = this.startOfLocalDay(d, tz);
        const diffDays = Math.floor((target.getTime() - start.getTime()) / (24 * 3600 * 1000));
        return diffDays >= 0 && diffDays % (s.every || 1) === 0;
      }

      case 'rrule': {
        try {
          // Evaluate RRULE in UTC, but based on the local day's bounds
          const start = new Date('2000-01-01T00:00:00.000Z');
          const set = new RRuleSet();
          set.rrule(rrulestr(`DTSTART:${this.icalDate(start)}\nRRULE:${s.rule}`));
          const [begin, end] = this.localDayBounds(d, tz);
          const occur = set.between(begin, end, true);
          return occur.length > 0;
        } catch {
          return false;
        }
      }
    }
  }

  private computeNextStreak(habit: any, now: Date, tz: string): number {
    const last = habit.lastTick ? new Date(habit.lastTick) : null;
    if (!last) return 1;

    const lastKey = this.localDayKey(last, tz);
    const todayKey = this.localDayKey(now, tz);

    if (lastKey === todayKey) {
      return habit.streak; // already ticked today (shouldn't happen here due to earlier check)
    }

    // If last tick was "yesterday" in local time -> continue streak
    // Else -> reset streak to 1
    const y = this.localDayKey(this.addLocalDays(now, tz, -1), tz);
    return (lastKey === y) ? habit.streak + 1 : 1;
  }

  // ---------- Idempotency with Redis ----------

  private buildIdemKey(userId: string, habitId: string, localDayKey: string, idempotencyKey?: string): string {
    // localDayKey = YYYY-MM-DD in user tz
    const base = `idem:habit:${userId}:${habitId}:${localDayKey}`;
    return idempotencyKey ? `${base}:${idempotencyKey}` : base;
    // We scope to the day to allow multiple days to tick while still idempotent per day/key.
  }

  private async tryAcquireIdem(key: string): Promise<boolean> {
    // set if not exists with 24h expiry
    const ok = await this.redis.set(key, '1', 'EX', 24 * 3600, 'NX');
    return ok === 'OK';
  }

  // ---------- Events ----------

  private async logEvent(userId: string, type: string, payload: Record<string, unknown>) {
    try {
      await this.prisma.event.create({
        data: {
          userId,
          type,
          payload,
        },
      });
    } catch (e) {
      // Non-fatal
      console.error('Event log failed:', e);
    }
  }

  // ---------- Time helpers (timezone-aware day math) ----------

  private zoned(d: Date, tz: string): Date {
    // Convert to the same absolute time; for local day boundaries we format to parts
    // and reconstruct a local date when needed
    return new Date(d);
  }

  private localDayKey(d: Date, tz: string): string {
    const fmt = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' });
    return fmt.format(d); // "YYYY-MM-DD"
  }

  private startOfLocalDay(d: Date, tz: string): Date {
    const parts = this.parts(d, tz);
    return new Date(Date.UTC(parts.year, parts.month - 1, parts.day, 0, 0, 0, 0));
  }

  private localDayBounds(d: Date, tz: string): [Date, Date] {
    const start = this.startOfLocalDay(d, tz);
    const end = new Date(start.getTime() + 24 * 3600 * 1000 - 1);
    return [start, end];
  }

  private addLocalDays(d: Date, tz: string, days: number): Date {
    const [start] = this.localDayBounds(d, tz);
    return new Date(start.getTime() + days * 24 * 3600 * 1000);
  }

  private parts(d: Date, tz: string): { year: number; month: number; day: number } {
    const fmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const str = fmt.format(d); // "YYYY-MM-DD"
    const parts = str.split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    return { year, month, day };
  }

  private icalDate(d: Date): string {
    // UTC-ish compact: YYYYMMDDT000000Z (we don't use time of day for RRULE base here)
    const pad = (n: number, l = 2) => String(n).padStart(l, '0');
    return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T000000Z`;
  }
}

export default HabitsService;
