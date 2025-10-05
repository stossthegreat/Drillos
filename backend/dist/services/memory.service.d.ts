import { Prisma } from '@prisma/client';
type FactsPatch = Record<string, any>;
type EventPayload = Record<string, any>;
export declare class MemoryService {
    /**
     * Append a raw event to the event stream (source of truth for memory).
     */
    appendEvent(userId: string, type: string, payload: EventPayload): Promise<{
        type: string;
        id: string;
        userId: string;
        ts: Date;
        payload: Prisma.JsonValue;
        embedding: Uint8Array | null;
    }>;
    /**
     * Merge/patch long-term user facts (JSON) with a deep merge.
     * Stores in UserFacts.json.
     */
    upsertFacts(userId: string, patch: FactsPatch): Promise<{
        updatedAt: Date;
        userId: string;
        json: Prisma.JsonValue;
    }>;
    /**
     * Fetch a compact context for AI: recent events, core facts, and rolling stats.
     */
    getUserContext(userId: string): Promise<{
        facts: Record<string, any>;
        recentEvents: {
            type: string;
            id: string;
            userId: string;
            ts: Date;
            payload: Prisma.JsonValue;
            embedding: Uint8Array | null;
        }[];
        habitSummaries: {
            id: string;
            title: string;
            streak: number;
            lastTick: Date;
            ticks30d: number;
        }[];
    }>;
    /**
     * Summarize the user's last 24h into a compact fact update and reflection.
     * This is called by the evening loop and applied to memory.
     */
    summarizeDay(userId: string): Promise<any>;
    /**
     * Small helper so mentors can retrieve a concise long-term profile.
     */
    getProfileForMentor(userId: string): Promise<{
        tz: string;
        tone: import(".prisma/client").$Enums.Tone;
        intensity: number;
        plan: import(".prisma/client").$Enums.Plan;
        bestTimes: any;
        weakDays: any;
        triggers: any;
        preferredRituals: any;
        lastReflection: any;
    }>;
    private deepMerge;
}
export declare const memoryService: MemoryService;
export {};
