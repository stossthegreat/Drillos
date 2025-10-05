type CreateHabitInput = {
    title: string;
    schedule: any;
    color?: string | null;
    context?: any;
    reminderEnabled?: boolean;
    reminderTime?: string | null;
};
type TickInput = {
    habitId: string;
    userId: string;
    dateISO?: string;
    idempotencyKey?: string;
};
export declare class HabitsService {
    list(userId: string): Promise<{
        status: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        schedule: import("@prisma/client/runtime/library").JsonValue;
        streak: number;
        lastTick: Date | null;
        color: string;
        context: import("@prisma/client/runtime/library").JsonValue;
        reminderEnabled: boolean;
        reminderTime: string | null;
    }[]>;
    getById(id: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        schedule: import("@prisma/client/runtime/library").JsonValue;
        streak: number;
        lastTick: Date | null;
        color: string;
        context: import("@prisma/client/runtime/library").JsonValue;
        reminderEnabled: boolean;
        reminderTime: string | null;
    }>;
    create(userId: string, input: CreateHabitInput): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        title: string;
        schedule: import("@prisma/client/runtime/library").JsonValue;
        streak: number;
        lastTick: Date | null;
        color: string;
        context: import("@prisma/client/runtime/library").JsonValue;
        reminderEnabled: boolean;
        reminderTime: string | null;
    }>;
    delete(id: string, userId: string): Promise<{
        ok: boolean;
        error: string;
        deleted?: undefined;
    } | {
        ok: boolean;
        deleted: {
            id: string;
            title: string;
            streak: number;
        };
        error?: undefined;
    }>;
    tick({ habitId, userId, dateISO, idempotencyKey }: TickInput): Promise<{
        ok: boolean;
        message: string;
        idempotent?: undefined;
        streak?: undefined;
        timestamp?: undefined;
    } | {
        ok: boolean;
        idempotent: boolean;
        message: string;
        streak: number;
        timestamp: Date;
    } | {
        ok: boolean;
        idempotent: boolean;
        message: string;
        streak: number;
        timestamp: string;
    }>;
    private logEvent;
}
export {};
