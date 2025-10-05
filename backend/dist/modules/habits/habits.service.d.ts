import { PrismaClient } from '@prisma/client';
import IORedis from 'ioredis';
type DaysAbbr = 'sun' | 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat';
type ScheduleJson = {
    type: 'daily';
    time?: string;
} | {
    type: 'weekdays';
    time?: string;
} | {
    type: 'weekends';
    time?: string;
} | {
    type: 'daysOfWeek';
    days: DaysAbbr[];
    time?: string;
} | {
    type: 'everyN';
    every: number;
    startDate: string;
    time?: string;
} | {
    type: 'rrule';
    rule: string;
    time?: string;
};
export interface CreateHabitInput {
    userId: string;
    title: string;
    schedule: ScheduleJson;
    color?: string;
    context?: Record<string, unknown>;
    reminderEnabled?: boolean;
    reminderTime?: string;
}
export interface UpdateHabitInput {
    title?: string;
    schedule?: ScheduleJson;
    color?: string;
    context?: Record<string, unknown>;
    reminderEnabled?: boolean;
    reminderTime?: string;
}
export interface TickResult {
    ok: boolean;
    idempotent: boolean;
    streak: number;
    timestamp: string;
    message: string;
}
export declare class HabitsService {
    private prisma;
    private redis;
    constructor(opts?: {
        prisma?: PrismaClient;
        redis?: IORedis;
    });
    list(userId: string, forDateISO?: string): Promise<(any & {
        status: 'pending' | 'completed_today';
    })[]>;
    create(input: CreateHabitInput): Promise<any>;
    update(habitId: string, userId: string, updates: UpdateHabitInput): Promise<any>;
    delete(habitId: string, userId: string): Promise<{
        ok: boolean;
        deleted: any;
    }>;
    tick(habitId: string, userId: string, opts?: {
        idempotencyKey?: string;
        dateISO?: string;
    }): Promise<TickResult>;
    private mustGetUser;
    private mustOwnHabit;
    private asSchedule;
    private normalizeSchedule;
    private isScheduledForDate;
    private computeNextStreak;
    private buildIdemKey;
    private tryAcquireIdem;
    private logEvent;
    private zoned;
    private localDayKey;
    private startOfLocalDay;
    private localDayBounds;
    private addLocalDays;
    private parts;
    private icalDate;
}
export default HabitsService;
//# sourceMappingURL=habits.service.d.ts.map