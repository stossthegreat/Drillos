import { prisma } from '../utils/db';
import { habitsService } from './habits.service';
import { tasksService } from './tasks.service';

export class TodayService {
  /**
   * Get all items (habits + tasks) selected for today
   */
  async getTodayItems(userId: string, dateString?: string) {
    const date = dateString
      ? dateString
      : new Date().toISOString().split('T')[0];

    const selections = await prisma.todaySelection.findMany({
      where: { userId, date },
      orderBy: { order: 'asc' },
    });

    const items: any[] = [];
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

  /**
   * Select a habit or task for today
   */
  async selectForToday(
    userId: string,
    habitId?: string,
    taskId?: string,
    dateString?: string
  ) {
    if (!habitId && !taskId) {
      throw new Error('Either habitId or taskId must be provided');
    }

    const date = dateString
      ? dateString
      : new Date().toISOString().split('T')[0];

    // Check if already selected
    const existing = await prisma.todaySelection.findFirst({
      where: {
        userId,
        date,
        OR: [{ habitId }, { taskId }],
      },
    });
    if (existing) {
      return existing; // Already selected
    }

    // Get max order for the day
    const maxOrder = await prisma.todaySelection.aggregate({
      where: { userId, date },
      _max: { order: true },
    });
    const newOrder = (maxOrder._max.order || 0) + 1;

    // Create new selection
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

  /**
   * Deselect (remove) a habit or task from today
   */
  async deselectForToday(
    userId: string,
    habitId?: string,
    taskId?: string,
    dateString?: string
  ) {
    const date = dateString
      ? dateString
      : new Date().toISOString().split('T')[0];

    const existing = await prisma.todaySelection.findFirst({
      where: {
        userId,
        date,
        OR: [{ habitId }, { taskId }],
      },
    });

    if (existing) {
      await prisma.todaySelection.delete({
        where: { id: existing.id },
      });
      return existing;
    }

    return null;
  }
}

export const todayService = new TodayService();
