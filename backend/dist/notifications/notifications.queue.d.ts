export declare class NotificationsQueue {
    private readonly queue;
    constructor();
    enqueuePush(payload: {
        userId: string;
        title: string;
        body: string;
        data?: Record<string, string>;
        audioUrl?: string | null;
    }): Promise<void>;
    close(): Promise<void>;
}
export default NotificationsQueue;
//# sourceMappingURL=notifications.queue.d.ts.map