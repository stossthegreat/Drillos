import { prisma } from "../utils/db";
import { Prisma } from "@prisma/client";
import { todayService } from "./today.service";

type CreateTaskInput = {
  title: string;
  description?: string;
  dueDate?: Date;
  priority?: number;
  category?: string;
};

type UpdateTaskInput = {
  title?: string;
  description?: string;
  dueDate?: Date;
  priority?: number;
  category?: string;
  completed?: boolean;
  completedAt?: Date;
};

export class TasksService {
  async list(userId: string, includeCompleted: boolean = false) {
    const tasks = await prisma.task.findMany({
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

  async getById(taskId: string, userId: string) {
    return prisma.task.findFirst({ where: { id: taskId, userId } });
  }

  async create(userId: string, input: CreateTaskInput) {
    const task = await prisma.task.create({
      data: {
        userId,
        title: input.title,
        description: input.description,
        dueDate: input.dueDate,
        priority: input.priority ?? 2,
        category: input.category ?? "general",
      },
    });

    await this.logEvent(userId, "task_created", { taskId: task.id, title: task.title });

    // ✅ Auto-select if due today or no dueDate
    const isToday =
      !task.dueDate ||
      task.dueDate.toISOString().split("T")[0] === new Date().toISOString().split("T")[0];

    if (isToday) {
      try {
        await todayService.selectForToday(userId, undefined, task.id);
      } catch {
        // ignore if already exists (unique constraint)
      }
    }

    return task;
  }

  async update(taskId: string, userId: string, updates: UpdateTaskInput) {
    const task = await prisma.task.findFirst({ where: { id: taskId, userId } });
    if (!task) throw new Error("Task not found");

    const data: Prisma.TaskUpdateInput = {
      title: updates.title,
      description: updates.description,
      dueDate: updates.dueDate,
      priority: updates.priority,
      category: updates.category,
      completed: updates.completed,
      completedAt: updates.completedAt,
    };

    const updated = await prisma.task.update({ where: { id: taskId }, data });

    await this.logEvent(userId, "task_updated", {
      taskId,
      title: updated.title,
      updates,
    });

    return updated;
  }

  async complete(taskId: string, userId: string) {
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
    await todayService.deselectForToday(userId, undefined, taskId);

    return { ok: true, taskId, completedAt: updated.completedAt };
  }

  async delete(taskId: string, userId: string) {
    const task = await prisma.task.findFirst({ where: { id: taskId, userId } });
    if (!task) throw new Error("Task not found");

    await prisma.$transaction([
      prisma.todaySelection.deleteMany({ where: { userId, taskId } }),
      prisma.task.delete({ where: { id: taskId } }),
    ]);

    await this.logEvent(userId, "task_deleted", { taskId, title: task.title });

    return { ok: true, deleted: { id: taskId, title: task.title } };
  }

  private async logEvent(userId: string, type: string, payload: any) {
    await prisma.event.create({ data: { userId, type, payload } });
  }
}

export const tasksService = new TasksService();
