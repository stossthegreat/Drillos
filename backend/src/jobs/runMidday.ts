// src/jobs/runMidday.ts
import { userService } from '../services/user.service';
import { NudgesService } from '../services/nudges.service';
import { notificationsService } from '../services/notifications.service';

const nudgesService = new NudgesService();

export async function runMidday() {
  console.log('[cron] runMidday');
  const users = await (userService as any).listActiveUsers?.() || [];
  for (const u of users) {
    const userId = u.id;
    if (!userId) continue;
    try {
      // Generate midday nudges (stricter if slacking)
      const nudges = await nudgesService.generateNudges(userId);
      for (const n of nudges) {
        await notificationsService.send(userId, 'Midday Push', n.message);
      }
    } catch (err) {
      console.error('[cron] runMidday error', userId, err);
    }
  }
}
