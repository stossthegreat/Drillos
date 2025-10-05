export declare class BriefService {
    getTodaysBrief(userId: string): Promise<{
        mentor: string;
        message: string;
        audio: string;
        missions: {
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
        }[];
        habits: {
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
        }[];
        tasks: {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            userId: string;
            title: string;
            description: string | null;
            dueDate: Date | null;
            priority: number;
            category: string | null;
            completed: boolean;
            completedAt: Date | null;
        }[];
        today: ({
            id: string;
            name: string;
            type: string;
            completed: boolean;
            streak: number;
            color: any;
            reminderEnabled: any;
            reminderTime: any;
            priority?: undefined;
        } | {
            id: string;
            name: string;
            type: string;
            completed: boolean;
            priority: number;
            streak?: undefined;
            color?: undefined;
            reminderEnabled?: undefined;
            reminderTime?: undefined;
        })[];
    }>;
    getEveningDebrief(userId: string): Promise<{
        mentor: string;
        message: string;
        audio: string;
        stats: {
            completed: number;
            total: number;
        };
    }>;
}
export declare const briefService: BriefService;
