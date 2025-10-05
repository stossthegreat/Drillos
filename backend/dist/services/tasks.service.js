"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tasksService = exports.TasksService = void 0;
const db_1 = require("../utils/db");
const today_service_1 = require("./today.service");
class TasksService {
    async list(userId, includeCompleted = false) {
        const tasks = await db_1.prisma.task.findMany({
            where: {
                userId,
                completed: includeCompleted ? undefined : false,
            },
            orderBy: { createdAt: "asc" },
        });
        return tasks.map((t) => ({
            ...t,
            overdue: t.dueDate ? new Date(t.dueDate) < new Date() && !t.completed : false,
            status: t.completed ? "completed" : "pending",
        }));
    }
    async getById(taskId, userId) {
        return db_1.prisma.task.findFirst({ where: { id: taskId, userId } });
    }
    async create(userId, input) {
        const task = await db_1.prisma.task.create({
            data: {
                userId,
                title: input.title,
                description: input.description,
                dueDate: input.dueDate,
                schedule: input.schedule ?? { type: "daily" },
                priority: input.priority ?? 2,
                category: input.category ?? "general",
            },
        });
        await this.logEvent(userId, "task_created", { taskId: task.id, title: task.title });
        // Auto-select if today matches the schedule
        if (this.isScheduledToday(task.schedule)) {
            try {
                const existing = await db_1.prisma.todaySelection.findFirst({
                    where: { userId, taskId: task.id, date: this.dayKey(new Date()) },
                });
                if (!existing) {
                    await today_service_1.todayService.selectForToday(userId, undefined, task.id);
                }
            }
            catch (e) {
                console.warn("⚠️ Auto-select task skipped:", e);
            }
        }
        // ✅ Auto-select if due today or no dueDate
        const isToday = !task.dueDate ||
            task.dueDate.toISOString().split("T")[0] === new Date().toISOString().split("T")[0];
        if (isToday) {
            try {
                await today_service_1.todayService.selectForToday(userId, undefined, task.id);
            }
            catch {
                // ignore if already exists (unique constraint)
            }
        }
        return task;
    }
    async update(taskId, userId, updates) {
        const task = await db_1.prisma.task.findFirst({ where: { id: taskId, userId } });
        if (!task)
            throw new Error("Task not found");
        const data = {
            title: updates.title,
            description: updates.description,
            dueDate: updates.dueDate,
            priority: updates.priority,
            category: updates.category,
            completed: updates.completed,
            completedAt: updates.completedAt,
        };
        const updated = await db_1.prisma.task.update({ where: { id: taskId }, data });
        await this.logEvent(userId, "task_updated", {
            taskId,
            title: updated.title,
            updates,
        });
        return updated;
    }
    async complete(taskId, userId) {
        const updated = await this.update(taskId, userId, {
            completed: true,
            completedAt: new Date(),
        });
        await this.logEvent(userId, "task_completed", {
            taskId,
            title: updated.title,
            completedAt: updated.completedAt,
        });
        // ✅ Remove from today's selection
        await today_service_1.todayService.deselectForToday(userId, undefined, taskId);
        return { ok: true, taskId, completedAt: updated.completedAt };
    }
    async delete(taskId, userId) {
        const task = await db_1.prisma.task.findFirst({ where: { id: taskId, userId } });
        if (!task)
            throw new Error("Task not found");
        await db_1.prisma.$transaction([
            db_1.prisma.todaySelection.deleteMany({ where: { userId, taskId } }),
            db_1.prisma.task.delete({ where: { id: taskId } }),
        ]);
        await this.logEvent(userId, "task_deleted", { taskId, title: task.title });
        return { ok: true, deleted: { id: taskId, title: task.title } };
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
}
exports.TasksService = TasksService;
exports.tasksService = new TasksService();
