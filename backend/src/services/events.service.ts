import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export class EventsService {
  async logEvent(userId: string, type: string, payload: Record<string, any>) {
    return prisma.event.create({
      data: { userId, type, payload },
    });
  }

  async getRecentEvents(userId: string, limit = 50) {
    return prisma.event.findMany({
      where: { userId },
      orderBy: { ts: "desc" },
      take: limit,
    });
  }

  async getPatterns(userId: string) {
    const events = await this.getRecentEvents(userId, 200);
    const grouped: Record<string, number> = {};

    for (const ev of events) {
      grouped[ev.type] = (grouped[ev.type] || 0) + 1;
    }

    return grouped;
  }

  async summarizeForAI(userId: string) {
    // produce a text summary of recent events for OpenAI context
    const events = await this.getRecentEvents(userId, 30);
    return events.map(e => `${e.type} on ${e.ts.toISOString()}`).join("\n");
  }
}
