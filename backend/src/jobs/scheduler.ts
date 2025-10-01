// src/jobs/scheduler.ts
import cron from 'node-cron';
import { runMorning } from './runMorning';
import { runMidday } from './runMidday';
import { runEvening } from './runEvening';

const TZ = process.env.CRON_TZ || 'UTC';

// Defaults (can override in .env)
const MORNING_CRON = process.env.CRON_MORNING || '0 7 * * *';   // 07:00 daily
const MIDDAY_CRON  = process.env.CRON_MIDDAY  || '0 12 * * *';  // 12:00 daily
const EVENING_CRON = process.env.CRON_EVENING || '0 21 * * *';  // 21:00 daily

export function startScheduler() {
  cron.schedule(MORNING_CRON, () => runMorning().catch(console.error), { timezone: TZ });
  cron.schedule(MIDDAY_CRON,  () => runMidday().catch(console.error),  { timezone: TZ });
  cron.schedule(EVENING_CRON, () => runEvening().catch(console.error), { timezone: TZ });
  console.log(`[scheduler] started with TZ=${TZ} morning=${MORNING_CRON} midday=${MIDDAY_CRON} evening=${EVENING_CRON}`);
}

