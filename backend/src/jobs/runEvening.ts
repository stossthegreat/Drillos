// src/jobs/runEvening.ts
import { userService } from '../services/user.service';
import { BriefService } from '../services/brief.service';
import { notificationsService } from '../services/notifications.service';

const briefService = new BriefService();

export async function runEvening() {
  console.log('[cron] runEvening');
  const users = await (userService as any).listActiveUsers?.() || [];
  for (const u of users) {
    const userId = u.id;
    if (!userId) continue;
    try {
      // Evening debrief
      const brief = await briefService.getEveningDebrief(userId);
      await notificationsService.send(
        userId,
        'Daily Debrief',
        brief.message || 'Day complete. Review your performance.'
      );
    } catch (err) {
      console.error('[cron] runEvening error', userId, err);
    }
  }
}
