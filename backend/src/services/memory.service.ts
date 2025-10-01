// src/services/memory.service.ts
import { prisma } from "../utils/db";

/**
 * Durable long-term memory over Postgres (UserFacts.json).
 * - get(): returns entire JSON blob
 * - merge(): deep merge partial facts
 * - learnFromEvent(): updates memory based on event signal (simple rule-based starter)
 */
export class MemoryService {
  async get(userId: string): Promise<Record<string, any>> {
    const uf = await prisma.userFacts.findUnique({ where: { userId } });
    return (uf?.json as any) || {};
  }

  async replace(userId: string, full: Record<string, any>) {
    await prisma.userFacts.upsert({
      where: { userId },
      create: { userId, json: full },
      update: { json: full },
    });
    await prisma.event.create({
      data: { userId, type: "memory_replace", payload: { size: Object.keys(full || {}).length } },
    });
    return { ok: true };
  }

  async merge(userId: string, partial: Record<string, any>) {
    const current = await this.get(userId);
    const next = deepMerge(current, partial);

    await prisma.userFacts.upsert({
      where: { userId },
      create: { userId, json: next },
      update: { json: next },
    });

    await prisma.event.create({
      data: { userId, type: "memory_merge", payload: { keys: Object.keys(partial) } },
    });

    return next;
  }

  /**
   * Update memory from raw user events (starter rules):
   * - If habit_tick on same habit increases streak >= 7, mark as "habit_is_forming"
   * - If repeated "habit_missed", mark "danger_windows"
   */
  async learnFromEvent(userId: string, event: { type: string; payload: any }) {
    const mem = await this.get(userId);
    if (!mem.habits) mem.habits = {};

    if (event.type === "habit_tick" && event.payload?.habitId) {
      const hid = event.payload.habitId;
      const streak = event.payload.nextStreak ?? event.payload.streak;
      if (!mem.habits[hid]) mem.habits[hid] = {};
      mem.habits[hid].last_tick_date = event.payload.date;
      mem.habits[hid].streak = streak;
      if (typeof streak === "number" && streak >= 7) {
        mem.habits[hid].habit_is_forming = true;
      }
    }

    if (event.type === "habit_missed" && event.payload?.habitId) {
      const hid = event.payload.habitId;
      if (!mem.habits[hid]) mem.habits[hid] = {};
      mem.habits[hid].missed_count = (mem.habits[hid].missed_count || 0) + 1;
      if (!mem.danger_windows) mem.danger_windows = [];
      const ts = new Date().toISOString();
      mem.danger_windows.push({ when: ts, reason: "habit_missed", habitId: hid });
    }

    await prisma.userFacts.upsert({
      where: { userId },
      create: { userId, json: mem },
      update: { json: mem },
    });

    await prisma.event.create({
      data: { userId, type: "memory_learn", payload: { fromEvent: event.type } },
    });

    return mem;
  }
}

function deepMerge(a: any, b: any): any {
  if (Array.isArray(a) && Array.isArray(b)) return b; // replace arrays
  if (isObject(a) && isObject(b)) {
    const out: any = { ...a };
    for (const k of Object.keys(b)) out[k] = deepMerge(a[k], b[k]);
    return out;
  }
  return b === undefined ? a : b;
}
function isObject(x: any) {
  return x && typeof x === "object" && !Array.isArray(x);
}

export const memoryService = new MemoryService();
