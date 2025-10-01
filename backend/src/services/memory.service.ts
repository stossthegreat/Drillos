// src/services/memory.service.ts
import { prisma } from "../utils/db";
import { redis } from "../utils/redis";

export class MemoryService {
  async getUserFacts(userId: string) {
    // check cache first
    const cacheKey = `userfacts:${userId}`;
    const cached = await redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const facts = await prisma.userFacts.findUnique({ where: { userId } });
    const json = facts?.json || {};
    await redis.set(cacheKey, JSON.stringify(json), "EX", 60); // 1min cache
    return json;
  }

  async updateUserFacts(userId: string, newFacts: Record<string, any>) {
    await prisma.userFacts.upsert({
      where: { userId },
      create: { userId, json: newFacts },
      update: { json: newFacts },
    });
    await redis.del(`userfacts:${userId}`);
  }

  async appendPattern(userId: string, key: string, value: any) {
    const current = await this.getUserFacts(userId);
    current[key] = value;
    await this.updateUserFacts(userId, current);
  }
}
export const memoryService = new MemoryService();
