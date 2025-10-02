// src/services/habitLoop.service.ts
import { Queue, Worker, JobsOptions } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { aiService } from "./ai.service";

const queue = new Queue("habit-loop", { connection: redis });

export class HabitLoopService {
  async scheduleDailyCheck(userId: string, mentor: string) {
    const jobOpts: JobsOptions = { removeOnComplete: true, removeOnFail: true };
    await queue.add("daily-check", { userId, mentor }, jobOpts);
  }
}

new Worker(
  "habit-loop",
  async job => {
    if (job.name === "daily-check") {
      const { userId, mentor } = job.data;
      // analyse habits & events
      const habits = await prisma.habit.findMany({ where: { userId } });
      const events = await prisma.event.findMany({
        where: { userId },
        orderBy: { ts: "desc" },
        take: 20,
      });
      // create a mentor message proactively
      const text = await aiService.generateMentorReply(
        userId,
        mentor,
        "Daily proactive check-in"
      );
      await prisma.event.create({
        data: {
          userId,
          type: "os_nudge",
          payload: { text, habitsCount: habits.length, recentEvents: events },
        },
      });
      // push notification later (NotificationService will pick it up)
    }
  },
  { connection: redis }
);

export const habitLoopService = new HabitLoopService();
