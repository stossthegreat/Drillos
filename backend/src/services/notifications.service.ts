// src/services/notifications.service.ts
import admin from 'firebase-admin';
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';

// Lazy Firebase initialization - only when actually needed
function getFirebaseApp() {
  if (!admin.apps.length) {
    // Skip Firebase initialization during build process
    if (process.env.NODE_ENV === 'build' || process.env.RAILWAY_ENVIRONMENT === 'build') {
      return null;
    }
    
    // Validate required environment variables
    if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIREBASE_CLIENT_EMAIL || !process.env.FIREBASE_PRIVATE_KEY) {
      console.warn('⚠️ Firebase credentials not available, notifications will be disabled');
      return null;
    }
    
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
  }
  return admin.app();
}

export class NotificationsService {
  /**
   * Send a push notification (immediate).
   */
  async send(userId: string, title: string, body: string) {
    const firebaseApp = getFirebaseApp();
    if (!firebaseApp) {
      console.warn('⚠️ Firebase not available, skipping notification');
      return { ok: false, error: 'Firebase not available' };
    }

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
