"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificationsService = exports.NotificationsService = void 0;
// src/services/notifications.service.ts
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const db_1 = require("../utils/db");
const redis_1 = require("../utils/redis");
// Initialize Firebase only if credentials are properly configured
let firebaseInitialized = false;
function initializeFirebase() {
    if (firebaseInitialized || firebase_admin_1.default.apps.length > 0)
        return;
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY;
    // Only initialize if we have valid credentials (not placeholder values)
    if (projectId && clientEmail && privateKey &&
        !projectId.includes('your_') &&
        !clientEmail.includes('your_') &&
        !privateKey.includes('your_')) {
        try {
            firebase_admin_1.default.initializeApp({
                credential: firebase_admin_1.default.credential.cert({
                    projectId,
                    clientEmail,
                    privateKey: privateKey.replace(/\\n/g, '\n'),
                }),
            });
            firebaseInitialized = true;
        }
        catch (error) {
            console.warn('Firebase initialization failed:', error.message);
        }
    }
}
class NotificationsService {
    /**
     * Send a push notification (immediate).
     */
    async send(userId, title, body) {
        initializeFirebase();
        if (!firebaseInitialized) {
            console.warn('Firebase not initialized, skipping notification');
            return { ok: false, error: 'Firebase not configured' };
        }
        const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
        if (!user)
            throw new Error('User not found');
        if (!user.fcmToken)
            throw new Error('User missing fcmToken');
        const message = {
            notification: { title, body },
            token: user.fcmToken,
        };
        await firebase_admin_1.default.messaging().send(message);
        await db_1.prisma.event.create({
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
    async schedule(userId, title, body, delaySeconds) {
        const key = `notify:${userId}:${Date.now()}`;
        const payload = JSON.stringify({ userId, title, body });
        // Store in Redis with TTL, background worker will process
        await redis_1.redis.set(key, payload, 'EX', delaySeconds);
        await db_1.prisma.event.create({
            data: {
                userId,
                type: 'notification_scheduled',
                payload: { title, body, delaySeconds },
            },
        });
        return { ok: true, scheduledFor: Date.now() + delaySeconds * 1000 };
    }
}
exports.NotificationsService = NotificationsService;
exports.notificationsService = new NotificationsService();
