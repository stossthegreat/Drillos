import { Queue } from 'bullmq';
export declare const QUEUE_NAMES: {
    readonly EMAIL: "email";
    readonly NOTIFICATION: "notification";
    readonly ANALYTICS: "analytics";
    readonly VOICE: "voice";
    readonly HABIT_LOOP: "habit-loop";
};
export declare const JOB_TYPES: {
    readonly EMAIL: "email";
    readonly NOTIFICATION: "notification";
    readonly ANALYTICS: "analytics";
    readonly VOICE: "voice";
    readonly HABIT_LOOP: "habit-loop";
};
export declare const emailQueue: Queue<any, any, string, any, any, string>;
export declare const notificationQueue: Queue<any, any, string, any, any, string>;
export declare const analyticsQueue: Queue<any, any, string, any, any, string>;
export declare const voiceQueue: Queue<any, any, string, any, any, string>;
export declare const habitLoopQueue: Queue<any, any, string, any, any, string>;
export declare function checkQueueHealth(): Promise<Record<string, boolean>>;
export declare function closeAllQueues(): Promise<void>;
