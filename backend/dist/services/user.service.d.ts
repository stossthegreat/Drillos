export declare class UserService {
    getUser(userId: string): Promise<{
        id: string;
        email: string | null;
        tz: string;
        tone: import(".prisma/client").$Enums.Tone;
        intensity: number;
        consentRoast: boolean;
        safeWord: string | null;
        plan: import(".prisma/client").$Enums.Plan;
        mentorId: string | null;
        fcmToken: string | null;
        nudgesEnabled: boolean;
        briefsEnabled: boolean;
        debriefsEnabled: boolean;
        createdAt: Date;
        updatedAt: Date;
    }>;
    updateUser(userId: string, updates: {
        mentorId?: string;
        tone?: string;
        intensity?: number;
    }): Promise<{
        id: string;
        email: string | null;
        tz: string;
        tone: import(".prisma/client").$Enums.Tone;
        intensity: number;
        consentRoast: boolean;
        safeWord: string | null;
        plan: import(".prisma/client").$Enums.Plan;
        mentorId: string | null;
        fcmToken: string | null;
        nudgesEnabled: boolean;
        briefsEnabled: boolean;
        debriefsEnabled: boolean;
        createdAt: Date;
        updatedAt: Date;
    }>;
}
