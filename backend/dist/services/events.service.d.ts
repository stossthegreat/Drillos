export declare class EventsService {
    logEvent(userId: string, type: string, payload: Record<string, any>): Promise<{
        type: string;
        id: string;
        userId: string;
        ts: Date;
        payload: import("@prisma/client/runtime/library").JsonValue;
        embedding: Uint8Array | null;
    }>;
    getRecentEvents(userId: string, limit?: number): Promise<{
        type: string;
        id: string;
        userId: string;
        ts: Date;
        payload: import("@prisma/client/runtime/library").JsonValue;
        embedding: Uint8Array | null;
    }[]>;
    getPatterns(userId: string): Promise<Record<string, number>>;
    summarizeForAI(userId: string): Promise<string>;
}
