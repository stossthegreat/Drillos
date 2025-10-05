import { Queue } from "bullmq";
import { redis } from "../utils/redis";

export const schedulerQueue = new Queue("scheduler", { connection: redis });

/**
 * Boot the repeatable background jobs for DrillOS
 * NOTE: Worker is instantiated in src/workers/scheduler.worker.ts
 */
export async function bootstrapSchedulers() {
  console.log("🔧 Bootstrapping scheduler jobs...");
  
  // scan alarms every minute
  await schedulerQueue.add(
    "scan-alarms",
    {},
    { repeat: { every: 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure daily briefs hourly
  await schedulerQueue.add(
    "ensure-daily-briefs",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );

  // re-ensure random nudges hourly
  await schedulerQueue.add(
    "ensure-random-nudges",
    {},
    { repeat: { every: 60 * 60_000 }, removeOnComplete: true, removeOnFail: true }
  );
  
  console.log("✅ Scheduler jobs registered");
}
