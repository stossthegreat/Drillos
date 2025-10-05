"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventsService = void 0;
const db_1 = require("../utils/db");
class EventsService {
    async logEvent(userId, type, payload) {
        return db_1.prisma.event.create({
            data: { userId, type, payload },
        });
    }
    async getRecentEvents(userId, limit = 50) {
        return db_1.prisma.event.findMany({
            where: { userId },
            orderBy: { ts: "desc" },
            take: limit,
        });
    }
    async getPatterns(userId) {
        const events = await this.getRecentEvents(userId, 200);
        const grouped = {};
        for (const ev of events) {
            grouped[ev.type] = (grouped[ev.type] || 0) + 1;
        }
        return grouped;
    }
    async summarizeForAI(userId) {
        // produce a text summary of recent events for OpenAI context
        const events = await this.getRecentEvents(userId, 30);
        return events.map(e => `${e.type} on ${e.ts.toISOString()}`).join("\n");
    }
}
exports.EventsService = EventsService;
