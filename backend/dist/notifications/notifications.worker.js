import { Worker } from 'bullmq';
import IORedis from 'ioredis';
let admin = null;
try {
    admin = require('firebase-admin');
    if (admin && (!admin.apps || admin.apps.length === 0)) {
        const projectId = process.env.FIREBASE_PROJECT_ID;
        const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
        const privateKey = (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n');
        if (projectId && clientEmail && privateKey) {
            admin.initializeApp({
                credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
            });
            console.log('🔥 FCM initialized');
        }
        else {
            console.log('⚠️ FCM not configured (missing FIREBASE_* envs). Will log instead.');
            admin = null;
        }
    }
}
catch {
    console.log('⚠️ firebase-admin not installed or failed to load. Will log instead.');
    admin = null;
}
const connection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379', {
    maxRetriesPerRequest: null,
    enableReadyCheck: true,
});
async function sendPush(job) {
    const payload = job.data;
    if (admin && payload.fcmToken) {
        const message = {
            token: payload.fcmToken,
            notification: { title: payload.title, body: payload.body },
            data: payload.data || {},
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'alarms',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        'content-available': 1,
                    },
                },
            },
        };
        try {
            const id = await admin.messaging().send(message);
            console.log(`📣 FCM sent → job ${job.id} → messageId=${id}`);
            return { delivered: true, messageId: id };
        }
        catch (err) {
            console.error('❌ FCM failed:', err?.message || err);
            throw err;
        }
    }
    console.log('📣 PUSH (log only) →', JSON.stringify(payload, null, 2));
    return { delivered: true, simulated: true };
}
const worker = new Worker('notifications', async (job) => {
    if (job.name === 'push') {
        return await sendPush(job);
    }
    return { skipped: true };
}, { connection });
worker.on('completed', (job) => console.log(`✅ notifications job ${job.id} completed`));
worker.on('failed', (job, err) => console.error(`❌ notifications job ${job?.id} failed`, err?.message));
//# sourceMappingURL=notifications.worker.js.map