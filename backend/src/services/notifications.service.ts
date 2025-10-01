// src/services/notifications.service.ts
import admin from 'firebase-admin';
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

export class NotificationsService {
  /**
   * Send a push notification (immediate).
   */
  async send(userId: string, title: string, body: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error('User not found');
    if (!(user as any).fcmToken) throw new Error('User missing fcmToken');

    const message = {
      notification: { title, body },
      token: (user as any).fcmToken,
    };

    await admin.messaging().send(message);

    await prisma.event.create({
      data: {
        userId,
        type: 'notification_sent',
        payload: { title, body },
      },
    });

    return { ok: true };
  }

  /**
   * Queue a notification for later using Redis (delayed).
   */
  async schedule(userId: string, title: string, body: string, delaySeconds: number) {
    const key = `notify:${userId}:${Date.now()}`;
    const payload = JSON.stringify({ userId, title, body });

    // Store in Redis with TTL, background worker will process
    await redis.set(key, payload, 'EX', delaySeconds);

    await prisma.event.create({
      data: {
        userId,
        type: 'notification_scheduled',
        payload: { title, body, delaySeconds },
      },
    });

    return { ok: true, scheduledFor: Date.now() + delaySeconds * 1000 };
  }
}

export const notificationsService = new NotificationsService();
