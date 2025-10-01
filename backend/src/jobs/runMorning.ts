// src/jobs/runMorning.ts
import { userService } from '../services/user.service';
import { habitLoopService } from '../services/habitLoop.service';
import { notificationsService } from '../services/notifications.service';
import { NudgesService } from '../services/nudges.service';

const nudgesService = new NudgesService();

export async function runMorning() {
  console.log('[cron] runMorning');
  const users = await (userService as any).listActiveUsers?.() || [];
  for (const u of users) {
    const userId = u.id;
    if (!userId) continue;
    try {
      // 1) Run daily check
      await habitLoopService.scheduleDailyCheck(userId, u.mentorId || 'drill');

      // 2) Morning nudges
      const nudges = await nudgesService.generateNudges(userId);
      if (!nudges || nudges.length === 0) {
        await notificationsService.send(userId, 'Drill OS', 'Wake up soldier. Today your mission begins.');
      } else {
        for (const n of nudges) {
          await notificationsService.send(userId, 'Morning Brief', n.message);
        }
      }
    } catch (err) {
      console.error('[cron] runMorning error', userId, err);
    }
  }
}
