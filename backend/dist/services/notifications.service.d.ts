export declare class NotificationsService {
    /**
     * Send a push notification (immediate).
     */
    send(userId: string, title: string, body: string): Promise<{
        ok: boolean;
        error: string;
    } | {
        ok: boolean;
        error?: undefined;
    }>;
    /**
     * Queue a notification for later using Redis (delayed).
     */
    schedule(userId: string, title: string, body: string, delaySeconds: number): Promise<{
        ok: boolean;
        scheduledFor: number;
    }>;
}
export declare const notificationsService: NotificationsService;
