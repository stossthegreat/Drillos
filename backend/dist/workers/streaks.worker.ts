import { Worker } from "bullmq";
import { redis } from "../utils/redis";
import { StreaksService } from "../services/streaks.service";
import { notificationsService } from "../services/notifications.service";

const streaksService = new StreaksService();

// 🏅 Worker that checks streaks and pushes mentor-style alerts
new Worker(
  "streaks",
  async (job) => {
    const { userId } = job.data;

    const summary = await streaksService.getStreakSummary(userId);
    const achievements = await streaksService.getUserAchievements(userId);

    if (achievements.achievements.length > 0) {
      const latest = achievements.achievements.slice(-1)[0];
      await notificationsService.send(
        userId,
        "🏅 Achievement Unlocked",
        `You just hit a ${latest.title}. Keep the fire alive!`
      );
    }

    if (summary.overall < 2) {
      await notificationsService.send(
        userId,
        "⚠️ Streak at Risk",
        "Your habits are cooling off. Get back in the fight today."
      );
    }
  },
  { connection: redis }
);
