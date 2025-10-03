// src/services/notifications.service.ts
import admin from 'firebase-admin';
import { prisma } from '../utils/db';
import { redis } from '../utils/redis';

// Initialize Firebase only if credentials are properly configured
let firebaseInitialized = false;

function initializeFirebase() {
  if (firebaseInitialized || admin.apps.length > 0) return;
  
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;
  
  // Only initialize if we have valid credentials (not placeholder values)
  if (projectId && clientEmail && privateKey && 
      !projectId.includes('your_') && 
      !clientEmail.includes('your_') && 
      !privateKey.includes('your_')) {
    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey: privateKey.replace(/\\n/g, '\n'),
        }),
      });
      firebaseInitialized = true;
    } catch (error) {
      console.warn('Firebase initialization failed:', error.message);
    }
  }
}

export class NotificationsService {
  /**
   * Send a push notification (immediate).
   */
  async send(userId: string, title: string, body: string) {
    initializeFirebase();
    
    if (!firebaseInitialized) {
      console.warn('Firebase not initialized, skipping notification');
      return { ok: false, error: 'Firebase not configured' };
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
