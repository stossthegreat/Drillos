import { Worker } from 'bullmq';
interface EmailJobData {
    to: string;
    subject: string;
    html: string;
    text?: string;
    from: string;
    replyTo?: string;
}
export declare const emailWorker: Worker<EmailJobData, any, string>;
export default emailWorker;
//# sourceMappingURL=emailWorker.d.ts.map