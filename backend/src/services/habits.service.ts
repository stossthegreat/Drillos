// ✅ Backend no longer computes scheduling/streaks/XP.
// It only stores habits and logs ticks; frontend is source of truth for timing.

import { prisma } from "../utils/db";

export const habitsService = {
  async list(userId: string) {
    return prisma.habit.findMany({ where: { userId }, orderBy: { createdAt: "desc" } });
  },

  async create(userId: string, body: any) {
    // Body may include schedule info (startDate, endDate, daysOfWeek) for UX;
    // backend stores it, but does NOT act on it.
    return prisma.habit.create({
      data: {
        userId,
        title: body.title || body.name,
        color: body.color || "emerald",
        schedule: body.schedule || {}, // JSON
        // any other fields preserved
      }
    });
  },

  async update(userId: string, id: string, body: any) {
    // Security: ensure habit belongs to user
    const existing = await prisma.habit.findUnique({ where: { id } });
    if (!existing || existing.userId !== userId) throw new Error("not_found");
    return prisma.habit.update({
      where: { id },
      data: {
        title: body.title ?? body.name ?? existing.title,
        color: body.color ?? existing.color,
        schedule: body.schedule ?? existing.schedule
      }
    });
  },

  async remove(userId: string, id: string) {
    const existing = await prisma.habit.findUnique({ where: { id } });
    if (!existing || existing.userId !== userId) throw new Error("not_found");
    await prisma.habit.delete({ where: { id } });
    await prisma.event.create({
      data: { userId, type: "habit_deleted", payload: { habitId: id } }
    });
    return { ok: true };
  },

  async tick(userId: string, id: string, dateISO?: string) {
    // Log the tick only. Frontend computes streak/XP immediately.
    const when = dateISO ? new Date(dateISO) : new Date();
    await prisma.event.create({
      data: { userId, type: "habit_tick", payload: { habitId: id, when } }
    });
    return { ok: true };
  }
};
