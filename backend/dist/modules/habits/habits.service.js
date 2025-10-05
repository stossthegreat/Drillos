import { PrismaClient } from '@prisma/client';
import IORedis from 'ioredis';
import { RRuleSet, rrulestr } from 'rrule';
export class HabitsService {
    prisma;
    redis;
    constructor(opts) {
        this.prisma = opts?.prisma ?? new PrismaClient();
        this.redis = opts?.redis ?? new IORedis(process.env.REDIS_URL || 'redis://localhost:6379');
    }
    async list(userId, forDateISO) {
        const date = forDateISO ? new Date(forDateISO) : new Date();
        const user = await this.mustGetUser(userId);
        const habits = await this.prisma.habit.findMany({
            where: { userId },
            orderBy: { createdAt: 'asc' },
        });
        const todayKey = this.localDayKey(date, user.tz);
        return habits.map((h) => {
            const last = h.lastTick ? this.localDayKey(new Date(h.lastTick), user.tz) : null;
            const completedToday = last === todayKey;
            return {
                ...h,
                status: completedToday ? 'completed_today' : 'pending',
            };
        }).filter((h) => this.isScheduledForDate(this.asSchedule(h.schedule), date, user.tz));
    }
    async create(input) {
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
                reminderEnabled: input.reminderEnabled ?? false,
                reminderTime: input.reminderTime ?? '08:00',
            },
        });
        await this.logEvent(user.id, 'habit_created', { habitId: habit.id, title: habit.title });
        return habit;
    }
    async update(habitId, userId, updates) {
        await this.mustOwnHabit(habitId, userId);
        const data = { ...updates };
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
    async delete(habitId, userId) {
        await this.mustOwnHabit(habitId, userId);
        const deleted = await this.prisma.habit.delete({
            where: { id: habitId },
        });
        await this.logEvent(userId, 'habit_deleted', { habitId, title: deleted.title });
        return { ok: true, deleted };
    }
    async tick(habitId, userId, opts) {
        const user = await this.mustGetUser(userId);
        const habit = await this.mustOwnHabit(habitId, userId);
        const now = opts?.dateISO ? new Date(opts.dateISO) : new Date();
        const todayKey = this.localDayKey(now, user.tz);
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
        const idemKey = this.buildIdemKey(userId, habitId, todayKey, opts?.idempotencyKey);
        const gotLock = await this.tryAcquireIdem(idemKey);
        if (!gotLock) {
            const h2 = await this.prisma.habit.findUnique({ where: { id: habitId } });
            return {
                ok: true,
                idempotent: true,
                streak: h2?.streak ?? habit.streak,
                timestamp: h2?.lastTick ? new Date(h2.lastTick).toISOString() : new Date().toISOString(),
                message: 'Already completed today',
            };
        }
        const lastKey = habit.lastTick ? this.localDayKey(new Date(habit.lastTick), user.tz) : null;
        if (lastKey === todayKey) {
            return {
                ok: true,
                idempotent: true,
                streak: habit.streak,
                timestamp: new Date(habit.lastTick).toISOString(),
                message: 'Already completed today',
            };
        }
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
            timestamp: updated.lastTick.toISOString(),
            message: `Completed! Streak: ${updated.streak}`,
        };
    }
    async mustGetUser(userId) {
        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        if (!user)
            throw new Error('User not found');
        return user;
    }
    async mustOwnHabit(habitId, userId) {
        const habit = await this.prisma.habit.findUnique({ where: { id: habitId } });
        if (!habit || habit.userId !== userId) {
            throw new Error('Habit not found');
        }
        return habit;
    }
    asSchedule(raw) {
        if (!raw)
            return { type: 'daily' };
        if (typeof raw === 'string') {
            try {
                return JSON.parse(raw);
            }
            catch {
                return { type: 'daily' };
            }
        }
        return raw;
    }
    normalizeSchedule(s) {
        switch (s.type) {
            case 'daily':
            case 'weekdays':
            case 'weekends':
                return s;
            case 'daysOfWeek': {
                const valid = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
                const days = (s.days || []).filter((d) => {
                    return typeof d === 'string' && valid.includes(d);
                });
                return { ...s, days: Array.from(new Set(days)) };
            }
            case 'everyN': {
                const every = Math.max(1, Math.floor(Number(s.every || 1)));
                const startDate = s.startDate && !isNaN(Date.parse(s.startDate)) ? s.startDate : new Date().toISOString().slice(0, 10);
                return { ...s, every, startDate };
            }
            case 'rrule': {
                try {
                    rrulestr(`RRULE:${s.rule}`);
                }
                catch {
                    throw new Error('Invalid RRULE');
                }
                return s;
            }
            default:
                return { type: 'daily' };
        }
    }
    isScheduledForDate(s, date, tz) {
        const d = this.zoned(date, tz);
        const dow = d.getDay();
        switch (s.type) {
            case 'daily':
                return true;
            case 'weekdays':
                return dow >= 1 && dow <= 5;
            case 'weekends':
                return dow === 0 || dow === 6;
            case 'daysOfWeek': {
                const map = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
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
                    const start = new Date('2000-01-01T00:00:00.000Z');
                    const set = new RRuleSet();
                    set.rrule(rrulestr(`DTSTART:${this.icalDate(start)}\nRRULE:${s.rule}`));
                    const [begin, end] = this.localDayBounds(d, tz);
                    const occur = set.between(begin, end, true);
                    return occur.length > 0;
                }
                catch {
                    return false;
                }
            }
        }
    }
    computeNextStreak(habit, now, tz) {
        const last = habit.lastTick ? new Date(habit.lastTick) : null;
        if (!last)
            return 1;
        const lastKey = this.localDayKey(last, tz);
        const todayKey = this.localDayKey(now, tz);
        if (lastKey === todayKey) {
            return habit.streak;
        }
        const y = this.localDayKey(this.addLocalDays(now, tz, -1), tz);
        return (lastKey === y) ? habit.streak + 1 : 1;
    }
    buildIdemKey(userId, habitId, localDayKey, idempotencyKey) {
        const base = `idem:habit:${userId}:${habitId}:${localDayKey}`;
        return idempotencyKey ? `${base}:${idempotencyKey}` : base;
    }
    async tryAcquireIdem(key) {
        const ok = await this.redis.set(key, '1', 'EX', 24 * 3600, 'NX');
        return ok === 'OK';
    }
    async logEvent(userId, type, payload) {
        try {
            await this.prisma.event.create({
                data: {
                    userId,
                    type,
                    payload,
                },
            });
        }
        catch (e) {
            console.error('Event log failed:', e);
        }
    }
    zoned(d, tz) {
        return new Date(d);
    }
    localDayKey(d, tz) {
        const fmt = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' });
        return fmt.format(d);
    }
    startOfLocalDay(d, tz) {
        const parts = this.parts(d, tz);
        return new Date(Date.UTC(parts.year, parts.month - 1, parts.day, 0, 0, 0, 0));
    }
    localDayBounds(d, tz) {
        const start = this.startOfLocalDay(d, tz);
        const end = new Date(start.getTime() + 24 * 3600 * 1000 - 1);
        return [start, end];
    }
    addLocalDays(d, tz, days) {
        const [start] = this.localDayBounds(d, tz);
        return new Date(start.getTime() + days * 24 * 3600 * 1000);
    }
    parts(d, tz) {
        const fmt = new Intl.DateTimeFormat('en-CA', {
            timeZone: tz,
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        });
        const str = fmt.format(d);
        const parts = str.split('-');
        const year = Number(parts[0]);
        const month = Number(parts[1]);
        const day = Number(parts[2]);
        return { year, month, day };
    }
    icalDate(d) {
        const pad = (n, l = 2) => String(n).padStart(l, '0');
        return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T000000Z`;
    }
}
export default HabitsService;
//# sourceMappingURL=habits.service.js.map