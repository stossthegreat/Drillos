import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export class EventsService {
  async logEvent(userId: string, type: string, payload: Record<string, any>) {
    return prisma.event.create({
      data: {
        userId,
        type,
        payload,
      },
    });
  }

  async getRecentEvents(userId: string, limit = 20) {
    return prisma.event.findMany({
      where: { userId },
      orderBy: { ts: 'desc' },
      take: limit,
    });
  }

  async getPatterns(userId: string) {
    const events = await this.getRecentEvents(userId, 100);
    const grouped: Record<string, number> = {};

    events.forEach(ev => {
      grouped[ev.type] = (grouped[ev.type] || 0) + 1;
    });

    return grouped;
  }
}
