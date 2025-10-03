import { prisma } from "../utils/db";
import { HabitsService } from "./habits.service";
import { TasksService } from "./tasks.service";

const habitsService = new HabitsService();
const tasksService = new TasksService();

export class TodayService {
  async getTodayItems(userId: string, dateString?: string) {
    const date = dateString ? dateString : new Date().toISOString().split('T')[0];

    const selections = await prisma.todaySelection.findMany({
      where: { userId, date },
      orderBy: { order: 'asc' },
    });

    const items = [];
    for (const selection of selections) {
      if (selection.habitId) {
        const habit = await habitsService.getById(selection.habitId, userId);
        if (habit) {
          items.push({
            ...selection,
            type: 'habit',
            title: habit.title,
            details: habit,
          });
        }
      } else if (selection.taskId) {
        const task = await tasksService.getById(selection.taskId, userId);
        if (task) {
          items.push({
            ...selection,
            type: 'task',
            title: task.title,
            details: task,
          });
        }
      }
    }
    return items;
  }

  async selectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string) {
    if (!habitId && !taskId) {
      throw new Error("Either habitId or taskId must be provided");
    }
    const date = dateString ? dateString : new Date().toISOString().split('T')[0];

    // Check if already selected
    const existing = await prisma.todaySelection.findFirst({
      where: { userId, date, OR: [{ habitId }, { taskId }] },
    });
    if (existing) {
      return existing; // Already selected, return existing
    }

    // Get max order for the day
    const maxOrder = await prisma.todaySelection.aggregate({
      where: { userId, date },
      _max: { order: true },
    });
    const newOrder = (maxOrder._max.order || 0) + 1;

    const selection = await prisma.todaySelection.create({
      data: {
        userId,
        habitId,
        taskId,
        date,
        order: newOrder,
      },
    });
    return selection;
  }

  async deselectForToday(userId: string, habitId?: string, taskId?: string, dateString?: string) {
    if (!habitId && !taskId) {
      throw new Error("Either habitId or taskId must be provided");
    }
    const date = dateString ? dateString : new Date().toISOString().split('T')[0];

    const deleted = await prisma.todaySelection.deleteMany({
      where: { userId, date, OR: [{ habitId }, { taskId }] },
    });
    return { count: deleted.count };
  }

  async completeTodayItem(userId: string, selectionId: string) {
    const selection = await prisma.todaySelection.findUnique({ where: { id: selectionId, userId } });
    if (!selection) {
      throw new Error("Today selection not found");
    }

    if (selection.habitId) {
      await habitsService.tick({ habitId: selection.habitId, userId });
    } else if (selection.taskId) {
      await tasksService.complete(selection.taskId, userId);
    }

    return prisma.todaySelection.update({
      where: { id: selectionId },
      data: { completed: true },
    });
  }
}

export const todayService = new TodayService();
