export interface EmailJobData {
    to: string;
    subject: string;
    html: string;
    text?: string;
    from?: string;
    replyTo?: string;
}
export declare class EmailService {
    sendEmail(data: EmailJobData): Promise<void>;
    sendWelcomeEmail(to: string, name: string): Promise<void>;
    sendHabitReminder(to: string, habitTitle: string, streak: number): Promise<void>;
}
export declare const emailService: EmailService;
export default emailService;
