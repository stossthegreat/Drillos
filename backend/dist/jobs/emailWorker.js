import { Worker } from 'bullmq';
import { redisClient } from '../utils/redis';
export const emailWorker = new Worker('email', async (job) => {
    const { to, subject } = job.data;
    try {
        console.log(`Sending email to ${to}: ${subject}`);
        await new Promise(resolve => setTimeout(resolve, 1000));
        console.log(`Email sent successfully to ${to}`);
        return { success: true, messageId: `msg_${Date.now()}` };
    }
    catch (error) {
        console.error('Failed to send email:', error);
        throw error;
    }
}, {
    connection: redisClient.getClient(),
    concurrency: 5,
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
});
emailWorker.on('completed', (job) => {
    console.log(`Email job ${job.id} completed`);
});
emailWorker.on('failed', (job, err) => {
    console.error(`Email job ${job?.id} failed:`, err);
});
emailWorker.on('error', (err) => {
    console.error('Email worker error:', err);
});
export default emailWorker;
//# sourceMappingURL=emailWorker.js.map