import { prisma } from "../utils/db";
import { Prisma } from "@prisma/client";

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
    return prisma.task.findMany({
      where: {
        userId,
        completed: includeCompleted ? undefined : false,
      },
      orderBy: { createdAt: "asc" },
    });
  }

  async getById(taskId: string, userId: string) {
    return prisma.task.findFirst({
      where: { id: taskId, userId },
    });
  }

  async create(userId: string, input: CreateTaskInput) {
    const task = await prisma.task.create({
      data: {
        userId,
        title: input.title,
        description: input.description,
        dueDate: input.dueDate,
        priority: input.priority,
        category: input.category,
      },
    });
    return task;
  }

  async update(taskId: string, userId: string, updates: UpdateTaskInput) {
    const task = await prisma.task.findFirst({ where: { id: taskId, userId } });
    if (!task) {
      throw new Error("Task not found");
    }

    const data: Prisma.TaskUpdateInput = {
      title: updates.title,
      description: updates.description,
      dueDate: updates.dueDate,
      priority: updates.priority,
      category: updates.category,
      completed: updates.completed,
      completedAt: updates.completed ? new Date() : null,
    };

    return prisma.task.update({
      where: { id: taskId },
      data,
    });
  }

  async complete(taskId: string, userId: string) {
    return this.update(taskId, userId, { completed: true, completedAt: new Date() });
  }

  async delete(taskId: string, userId: string) {
    const task = await prisma.task.findFirst({ where: { id: taskId, userId } });
    if (!task) {
      throw new Error("Task not found");
    }
    await prisma.task.delete({ where: { id: taskId } });
    return { ok: true, deleted: { id: taskId, title: task.title } };
  }
}

export const tasksService = new TasksService();
