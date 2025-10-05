"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.habitsService = exports.HabitsService = void 0;
const db_1 = require("../utils/db");
const today_service_1 = require("./today.service");
class HabitsService {
    async list(userId) {
        const habits = await db_1.prisma.habit.findMany({
            where: { userId },
            orderBy: { createdAt: "asc" },
        });
        const todayKey = new Date().toISOString().split("T")[0];
        return habits.map((h) => ({
            ...h,
            completedToday: h.lastTick &&
                new Date(h.lastTick).toISOString().split("T")[0] === todayKey,
        }));
    }
    async getById(id, userId) {
        return db_1.prisma.habit.findFirst({ where: { id, userId } });
    }
    async create(userId, input) {
        const habit = await db_1.prisma.habit.create({
            data: {
                title: input.title,
                schedule: input.schedule ?? { type: "daily" },
                color: input.color ?? "emerald",
                streak: 0,
                lastTick: null,
                context: input.context ?? {},
                reminderEnabled: input.reminderEnabled ?? false,
                reminderTime: input.reminderTime ?? "08:00",
                user: { connect: { id: userId } },
            },
        });
        await this.logEvent(userId, "habit_created", {
            habitId: habit.id,
            title: habit.title,
        });
        // Auto-select if today matches the schedule, but don’t double-add
        if (this.isScheduledToday(habit.schedule)) {
            try {
                const existing = await db_1.prisma.todaySelection.findFirst({
                    where: { userId, habitId: habit.id, date: this.dayKey(new Date()) },
                });
                if (!existing) {
                    await today_service_1.todayService.selectForToday(userId, habit.id, undefined);
                }
            }
            catch (e) {
                console.warn("⚠️ Auto-select skipped:", e);
            }
        }
        return habit;
    }
    async delete(id, userId) {
        const habit = await db_1.prisma.habit.findFirst({ where: { id, userId } });
        if (!habit)
            return { ok: false, error: "Habit not found" };
        await db_1.prisma.$transaction([
            db_1.prisma.todaySelection.deleteMany({ where: { userId, habitId: id } }),
            db_1.prisma.habit.delete({ where: { id } }),
        ]);
        await this.logEvent(userId, "habit_deleted", {
            habitId: id,
            title: habit.title,
        });
        return { ok: true };
    }
    async tick({ habitId, userId, dateISO, idempotencyKey }) {
        const habit = await db_1.prisma.habit.findFirst({ where: { id: habitId, userId } });
        if (!habit)
            return { ok: false, message: "Habit not found" };
        const date = dateISO ? new Date(`${dateISO}T00:00:00Z`) : new Date();
        const dateKey = date.toISOString().split("T")[0];
        // prevent duplicates
        const existing = await db_1.prisma.event.findFirst({
            where: {
                userId,
                type: "habit_tick",
                payload: { path: ["habitId"], equals: habitId },
                ts: { gte: new Date(`${dateKey}T00:00:00Z`), lt: new Date(`${dateKey}T23:59:59Z`) },
            },
        });
        if (existing)
            return { ok: true, idempotent: true };
        const lastTick = habit.lastTick ? new Date(habit.lastTick) : null;
        const wasYesterday = lastTick && this.dayKey(lastTick) === this.dayKey(this.addDays(date, -1));
        const newStreak = wasYesterday ? habit.streak + 1 : 1;
        await db_1.prisma.habit.update({
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
    async logEvent(userId, type, payload) {
        await db_1.prisma.event.create({ data: { userId, type, payload } });
    }
    isScheduledToday(schedule) {
        if (!schedule || !schedule.type)
            return true;
        const today = new Date();
        const day = today.getDay();
        switch (schedule.type) {
            case "daily":
                return true;
            case "weekdays":
                return day >= 1 && day <= 5;
            case "everyN":
                if (!schedule.startDate || !schedule.everyN)
                    return true;
                const start = new Date(schedule.startDate);
                const diffDays = Math.floor((today.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
                return diffDays % schedule.everyN === 0;
            case "custom":
                if (schedule.startDate && today < new Date(schedule.startDate))
                    return false;
                if (schedule.endDate && today > new Date(schedule.endDate))
                    return false;
                return true;
            default:
                return true;
        }
    }
    dayKey(d) {
        return d.toISOString().split("T")[0];
    }
    addDays(d, n) {
        const x = new Date(d);
        x.setUTCDate(x.getUTCDate() + n);
        return x;
    }
}
exports.HabitsService = HabitsService;
exports.habitsService = new HabitsService();
