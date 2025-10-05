import { Worker } from "bullmq";
import { redis } from "../utils/redis";
import { notificationsService } from "../services/notifications.service";

new Worker(
  "notification",
  async (job) => {
    const { userId, title, body } = job.data;
    console.log(`📣 Worker sending notification -> ${userId}: ${title}`);
    await notificationsService.send(userId, title, body);
  },
  { connection: redis }
);
