export declare class AlarmsService {
    list(userId: string): Promise<{
        enabled: boolean;
        id: string;
        tone: import(".prisma/client").$Enums.Tone;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        label: string;
        rrule: string;
        nextRun: Date | null;
    }[]>;
    create(userId: string, data: {
        label: string;
        rrule: string;
        tone?: 'strict' | 'balanced' | 'light';
    }): Promise<{
        enabled: boolean;
        id: string;
        tone: import(".prisma/client").$Enums.Tone;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        label: string;
        rrule: string;
        nextRun: Date | null;
    }>;
    update(id: string, userId: string, changes: Partial<{
        label: string;
        rrule: string;
        enabled: boolean;
        tone: string;
    }>): Promise<{
        enabled: boolean;
        id: string;
        tone: import(".prisma/client").$Enums.Tone;
        createdAt: Date;
        updatedAt: Date;
        userId: string;
        label: string;
        rrule: string;
        nextRun: Date | null;
    }>;
    delete(id: string, userId: string): Promise<{
        ok: boolean;
    }>;
    markFired(id: string, userId: string): Promise<{
        ok: boolean;
        message: string;
        deduped?: undefined;
        nextRun?: undefined;
        voiceUrl?: undefined;
    } | {
        ok: boolean;
        deduped: boolean;
        message?: undefined;
        nextRun?: undefined;
        voiceUrl?: undefined;
    } | {
        ok: boolean;
        nextRun: Date;
        voiceUrl: string;
        message?: undefined;
        deduped?: undefined;
    }>;
}
export declare const alarmsService: AlarmsService;
