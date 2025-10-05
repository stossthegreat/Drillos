import { PrismaClient } from '@prisma/client';
interface NotificationQueue {
    enqueuePush: (payload: {
        userId: string;
        title: string;
        body: string;
        data?: Record<string, string>;
        audioUrl?: string | null;
    }) => Promise<void>;
}
interface VoiceService {
    getAudioUrl(input: {
        userId: string;
        mentor?: string;
        tone?: 'strict' | 'balanced' | 'light';
        presetId?: string;
        text?: string;
    }): Promise<{
        url: string | null;
    }>;
}
type CreateAlarmDTO = {
    label: string;
    rrule: string;
    tone?: 'strict' | 'balanced' | 'light';
    enabled?: boolean;
    metadata?: Record<string, any>;
};
type UpdateAlarmDTO = Partial<CreateAlarmDTO>;
export declare class AlarmsService {
    private prisma;
    private notifications;
    private voice;
    constructor(prisma?: PrismaClient, notifications?: NotificationQueue, voice?: VoiceService);
    list(userId: string): Promise<any>;
    create(userId: string, dto: CreateAlarmDTO): Promise<any>;
    update(userId: string, id: string, dto: UpdateAlarmDTO): Promise<any>;
    fire(userId: string, id: string): Promise<{
        ok: boolean;
        firedAt: string;
        nextRun: Date;
    }>;
    dismiss(userId: string, id: string, snoozeMinutes: number): Promise<{
        ok: boolean;
        nextRun: Date;
    }>;
    remove(userId: string, id: string): Promise<{
        ok: boolean;
        deleted: string;
    }>;
    private getOwned;
    private normalizeTone;
    private guessMentorFromTone;
    private buildMentorLine;
    private calculateNextRun;
    private logEvent;
}
export default AlarmsService;
//# sourceMappingURL=alarms.service.d.ts.map