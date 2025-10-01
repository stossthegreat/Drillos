import { emailQueue, JOB_TYPES } from '../utils/queue';

export interface EmailJobData {
  to: string;
  subject: string;
  html: string;
  text?: string;
  from?: string;
  replyTo?: string;
}

export class EmailService {
  async sendEmail(data: EmailJobData): Promise<void> {
    try {
      await emailQueue.add(JOB_TYPES.SEND_EMAIL, {
        ...data,
        from: data.from || process.env.FROM_EMAIL || 'noreply@drillos.com',
        replyTo: data.replyTo || process.env.REPLY_TO_EMAIL,
      }, {
        priority: 1,
        delay: 0,
      });
    } catch (error) {
      console.error('Failed to queue email:', error);
      throw new Error('Failed to queue email');
    }
  }

  async sendWelcomeEmail(to: string, name: string): Promise<void> {
    const subject = 'Welcome to Drillos!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333;">Welcome to Drillos!</h1>
        <p>Hi ${name},</p>
        <p>Welcome to Drillos! We're excited to help you build better habits and break bad ones.</p>
        <p>Get started by creating your first habit or setting up an alarm.</p>
        <p>Best regards,<br>The Drillos Team</p>
      </div>
    `;
    const text = `Welcome to Drillos! Hi ${name}, Welcome to Drillos! We're excited to help you build better habits and break bad ones. Get started by creating your first habit or setting up an alarm. Best regards, The Drillos Team`;

    await this.sendEmail({
      to,
      subject,
      html,
      text,
    });
  }

  async sendHabitReminder(to: string, habitTitle: string, streak: number): Promise<void> {
    const subject = `Don't break your streak! - ${habitTitle}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333;">Keep your streak alive! 🔥</h1>
        <p>You're on a ${streak}-day streak with "${habitTitle}"!</p>
        <p>Don't let it slip away. Take action now!</p>
        <p>Best regards,<br>The Drillos Team</p>
      </div>
    `;
    const text = `Keep your streak alive! You're on a ${streak}-day streak with "${habitTitle}"! Don't let it slip away. Take action now! Best regards, The Drillos Team`;

    await this.sendEmail({
      to,
      subject,
      html,
      text,
    });
  }
}

export const emailService = new EmailService();
export default emailService;
