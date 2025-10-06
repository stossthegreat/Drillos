// ✅ Frontend now owns habit scheduling, streaks, XP, alarms.
// This scheduler exists ONLY for OS brain tasks: briefs and nudges.

import { Queue } from "bullmq";
import { redis } from "../utils/redis";

export const schedulerQueue = new Queue("scheduler", { connection: redis });

export async function bootstrapSchedulers() {
  console.log("⏰ Schedulers active (OS brain only)");

  // Morning brief (7AM) per user will be upserted hourly by ensure-daily-briefs
  await schedulerQueue.add("ensure-daily-briefs", {}, {
    repeat: { every: 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true
  });

  // Evening debrief (9PM) per user
  await schedulerQueue.add("ensure-evening-debriefs", {}, {
    repeat: { every: 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true
  });

  // AI nudges hourly (we decide if/when to send)
  await schedulerQueue.add("auto-nudges-hourly", {}, {
    repeat: { every: 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true
  });
}
