// src/services/memory.service.ts
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';
import { Prisma } from '@prisma/client';
import OpenAI from 'openai';
import { MENTORS } from '../config/mentors.config';

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS || 400);
const LLM_TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS || 10000);

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  timeout: LLM_TIMEOUT_MS,
});

type FactsPatch = Record<string, any>;
type EventPayload = Record<string, any>;

export class MemoryService {
  /**
   * Append a raw event to the event stream (source of truth for memory).
   */
  async appendEvent(userId: string, type: string, payload: EventPayload) {
    return prisma.event.create({
      data: { userId, type, payload },
    });
  }

  /**
   * Merge/patch long-term user facts (JSON) with a deep merge.
   * Stores in UserFacts.json.
   */
  async upsertFacts(userId: string, patch: FactsPatch) {
    const existing = await prisma.userFacts.findUnique({ where: { userId } });
    if (!existing) {
      return prisma.userFacts.create({
        data: { userId, json: patch as Prisma.InputJsonValue },
      });
    }
    const merged = this.deepMerge(existing.json as Record<string, any>, patch);
    return prisma.userFacts.update({
      where: { userId },
      data: { json: merged as Prisma.InputJsonValue },
    });
  }

  /**
   * Fetch a compact context for AI: recent events, core facts, and rolling stats.
   */
  async getUserContext(userId: string) {
    const facts = await prisma.userFacts.findUnique({ where: { userId } });
    const recentEvents = await prisma.event.findMany({
      where: { userId },
      orderBy: { ts: 'desc' },
      take: 100,
    });

    // Rolling stats: last 30 days habit ticks, misses, most common times, etc.
    const since = new Date();
    since.setDate(since.getDate() - 30);

    const recentTicks = await prisma.event.findMany({
      where: {
        userId,
        type: 'habit_tick',
        ts: { gte: since },
      },
      orderBy: { ts: 'desc' },
      take: 1000,
    });

    const perHabit: Record<string, { ticks: number; lastDate: string | null }> = {};
    for (const ev of recentTicks) {
      const hid = (ev.payload as any)?.habitId;
      if (!hid) continue;
      perHabit[hid] = perHabit[hid] || { ticks: 0, lastDate: null };
      perHabit[hid].ticks += 1;
      perHabit[hid].lastDate = (ev.payload as any)?.date || perHabit[hid].lastDate;
    }

    const habits = await prisma.habit.findMany({ where: { userId } });
    const habitSummaries = habits.map((h) => ({
      id: h.id,
      title: h.title,
      streak: h.streak,
      lastTick: h.lastTick,
      ticks30d: perHabit[h.id]?.ticks || 0,
    }));

    return {
      facts: (facts?.json as Record<string, any>) || {},
      recentEvents,
      habitSummaries,
    };
  }

  /**
   * Summarize the user's last 24h into a compact fact update and reflection.
   * This is called by the evening loop and applied to memory.
   */
  async summarizeDay(userId: string) {
    // cache-key to avoid double-charge if retried
    const cacheKey = `mem:summary:${userId}:${new Date().toISOString().slice(0, 10)}`;
    const cached = await redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const context = await this.getUserContext(userId);

    const system = [
      `You are the memory engine for a discipline OS.`,
      `Input: user facts, recent events, and habit summaries.`,
      `Output: JSON with:`,
      `  - "factsPatch": concise updates to persistent memory (e.g. bestTimes, weakDays, preferredTone, triggers)`,
      `  - "reflection": 1-2 sentence narrative reflection on the day (short, powerful, mentor-agnostic)`,
      `Keep it compact and strictly valid JSON.`,
    ].join('\n');

    const user = {
      facts: context.facts,
      habitSummaries: context.habitSummaries,
      recentEvents: context.recentEvents.slice(0, 60).map(e => ({
        ts: e.ts,
        type: e.type,
        payload: e.payload,
      })),
    };

    const completion = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      temperature: 0.2,
      max_tokens: LLM_MAX_TOKENS,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: JSON.stringify(user) },
      ],
      response_format: { type: 'json_object' as any },
    });

    const raw = completion.choices[0]?.message?.content || '{}';
    let parsed: { factsPatch?: Record<string, any>; reflection?: string } = {};
    try { parsed = JSON.parse(raw); } catch { parsed = { factsPatch: {}, reflection: '' }; }

    const patch = parsed.factsPatch || {};
    if (Object.keys(patch).length) {
      await this.upsertFacts(userId, patch);
      await this.appendEvent(userId, 'memory_updated', { patch });
    }
    if (parsed.reflection) {
      await this.appendEvent(userId, 'day_reflection', { text: parsed.reflection });
    }

    const out = { patch, reflection: parsed.reflection || '' };
    await redis.set(cacheKey, JSON.stringify(out), 'EX', 60 * 60 * 6);
    return out;
  }

  /**
   * Small helper so mentors can retrieve a concise long-term profile.
   */
  async getProfileForMentor(userId: string) {
    const factsRow = await prisma.userFacts.findUnique({ where: { userId } });
    const facts = (factsRow?.json as Record<string, any>) || {};
    const user = await prisma.user.findUnique({ where: { id: userId } });

    return {
      tz: user?.tz || 'UTC',
      tone: user?.tone || 'balanced',
      intensity: user?.intensity || 2,
      plan: user?.plan || 'FREE',
      bestTimes: facts.bestTimes || null,
      weakDays: facts.weakDays || null,
      triggers: facts.triggers || null,
      preferredRituals: facts.preferredRituals || null,
      lastReflection: facts.lastReflection || null,
    };
  }

  private deepMerge(a: Record<string, any>, b: Record<string, any>) {
    const out = { ...a };
    for (const k of Object.keys(b)) {
      const av = (a as any)[k];
      const bv = (b as any)[k];
      if (av && typeof av === 'object' && !Array.isArray(av) && typeof bv === 'object' && !Array.isArray(bv)) {
        (out as any)[k] = this.deepMerge(av, bv);
      } else {
        (out as any)[k] = bv;
      }
    }
    return out;
  }
}

export const memoryService = new MemoryService();
