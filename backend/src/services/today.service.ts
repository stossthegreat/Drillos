import { prisma } from "../utils/db";

export class TodayService {
  async getTodayItems(userId: string, dateString?: string) {
    const date = dateString || new Date().toISOString().split("T")[0];
    const selections = await prisma.todaySelection.findMany({
      where: { userId, date },
      orderBy: { order: "asc" },
      include: { habit: true, task: true },
    });

    return selections.map((s) => ({
      id: s.id,
      type: s.habitId ? "habit" : "task",
      title: s.habit?.title || s.task?.title,
      completed:
        s.habitId && s.habit?.lastTick
          ? new Date(s.habit.lastTick).toISOString().split("T")[0] === date
          : s.task?.completed ?? false,
      color: s.habit?.color || "emerald",
      streak: s.habit?.streak || 0,
      // Task doesn’t have reminder fields
      reminderEnabled: s.habit?.reminderEnabled ?? false,
      reminderTime: s.habit?.reminderTime ?? null,
    }));
  }

  async selectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string) {
    const date = dateString || new Date().toISOString().split("T")[0];
    if (!habitId && !taskId) throw new Error("habitId or taskId required");

    const existing = await prisma.todaySelection.findFirst({
      where: { userId, date, OR: [{ habitId }, { taskId }] },
    });
    if (existing) return existing;

    const maxOrder = await prisma.todaySelection.aggregate({
      where: { userId, date },
      _max: { order: true },
    });
    const order = (maxOrder._max.order || 0) + 1;

    return prisma.todaySelection.create({
      data: { userId, habitId, taskId, date, order },
    });
  }

  async deselectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string) {
    const date = dateString || new Date().toISOString().split("T")[0];
    const existing = await prisma.todaySelection.findFirst({
      where: { userId, date, OR: [{ habitId }, { taskId }] },
    });
    if (!existing) return null;
    await prisma.todaySelection.delete({ where: { id: existing.id } });
    return existing;
  }
}

export const todayService = new TodayService();
