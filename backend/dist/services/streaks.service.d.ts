export declare class StreaksService {
    /**
     * Get a summary of the user’s overall streaks.
     * Returns total streaks, best streak, average, and per-habit breakdown.
     */
    getStreakSummary(userId: string): Promise<{
        overall: number;
        bestStreak: number;
        avgStreak: number;
        habits: {
            id: string;
            title: string;
            streak: number;
            lastTick: Date;
        }[];
    }>;
    /**
     * Build gamified achievement data from streaks.
     */
    getUserAchievements(userId: string): Promise<{
        totalXP: number;
        level: number;
        achievements: {
            id: string;
            title: string;
            unlocked: boolean;
        }[];
        rank: string;
        pendingCelebrations: {
            id: string;
            title: string;
            unlocked: boolean;
        }[];
    }>;
    /**
     * Translate level → rank name.
     */
    private calculateRank;
}
export declare const streaksService: StreaksService;
