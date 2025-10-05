"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.todayService = exports.TodayService = void 0;
const db_1 = require("../utils/db");
class TodayService {
    async getTodayItems(userId, dateString) {
        const date = dateString || new Date().toISOString().split("T")[0];
        const selections = await db_1.prisma.todaySelection.findMany({
            where: { userId, date },
            orderBy: { order: "asc" },
            include: { habit: true, task: true },
        });
        return selections.map((s) => ({
            id: s.id,
            type: s.habitId ? "habit" : "task",
            title: s.habit?.title || s.task?.title,
            completed: s.habitId && s.habit?.lastTick
                ? new Date(s.habit.lastTick).toISOString().split("T")[0] === date
                : s.task?.completed ?? false,
            color: s.habit?.color || "emerald",
            streak: s.habit?.streak || 0,
            // Task doesn’t have reminder fields
            reminderEnabled: s.habit?.reminderEnabled ?? false,
            reminderTime: s.habit?.reminderTime ?? null,
        }));
    }
    async selectForToday(userId, habitId, taskId, dateString) {
        const date = dateString || new Date().toISOString().split("T")[0];
        if (!habitId && !taskId)
            throw new Error("habitId or taskId required");
        const existing = await db_1.prisma.todaySelection.findFirst({
            where: { userId, date, OR: [{ habitId }, { taskId }] },
        });
        if (existing)
            return existing;
        const maxOrder = await db_1.prisma.todaySelection.aggregate({
            where: { userId, date },
            _max: { order: true },
        });
        const order = (maxOrder._max.order || 0) + 1;
        return db_1.prisma.todaySelection.create({
            data: { userId, habitId, taskId, date, order },
        });
    }
    async deselectForToday(userId, habitId, taskId, dateString) {
        const date = dateString || new Date().toISOString().split("T")[0];
        const existing = await db_1.prisma.todaySelection.findFirst({
            where: { userId, date, OR: [{ habitId }, { taskId }] },
        });
        if (!existing)
            return null;
        await db_1.prisma.todaySelection.delete({ where: { id: existing.id } });
        return existing;
    }
}
exports.TodayService = TodayService;
exports.todayService = new TodayService();
