import { Worker, Job } from 'bullmq';
import { redisClient } from '../utils/redis';

interface EmailJobData {
  to: string;
  subject: string;
  html: string;
  text?: string;
  from: string;
  replyTo?: string;
}

// Email worker
export const emailWorker = new Worker(
  'email',
  async (job: Job<EmailJobData>) => {
    const { to, subject } = job.data;

    try {
      // In a real implementation, you would integrate with an email service like:
      // - SendGrid
      // - AWS SES
      // - Mailgun
      // - Nodemailer with SMTP
      
      console.log(`Sending email to ${to}: ${subject}`);
      
      // Simulate email sending
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      console.log(`Email sent successfully to ${to}`);
      
      return { success: true, messageId: `msg_${Date.now()}` };
    } catch (error) {
      console.error('Failed to send email:', error);
      throw error;
    }
  },
  {
    connection: redisClient.getClient(),
    concurrency: 5,
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  }
);

// Event handlers
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
