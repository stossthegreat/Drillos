import { Queue } from 'bullmq';
export declare const schedulerQueue: Queue<any, any, string, any, any, string>;
/**
 * Bootstrap repeatable jobs once at boot.
 * - scan-alarms: every minute
 * - ensure-daily-briefs: hourly (sets cron per user 07:00 local)
 * - auto-nudges: hourly
 * - ensure-evening-debriefs: hourly (sets cron per user 21:00 local)
 */
export declare function bootstrapSchedulers(): Promise<void>;
