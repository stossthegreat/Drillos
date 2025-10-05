type Nudge = {
    type: 'streak_save' | 'daily_reminder' | 'momentum' | 'reflection';
    title: string;
    message: string;
    priority: 'low' | 'medium' | 'high';
    audioPresetId?: string;
};
export declare class BriefService {
    ensureDailyBriefAlarms(userId: string, tz?: string): Promise<{
        ok: boolean;
    }>;
    private getNextMilestone;
    private daysBetween;
    private buildNudges;
    getMorningBrief(userId: string): Promise<{
        missions: any;
        riskBanners: any;
        nudges: Nudge[];
        weeklyTarget: {
            current: number;
            goal: number;
        };
        sentiment: {
            energy: string;
            focus: string;
            suggestion: string;
        };
    }>;
    getEveningBrief(userId: string): Promise<{
        completed: any;
        total: any;
        completion: number;
        reflections: string[];
        suggestion: string;
    }>;
    pushMorningBrief(userId: string, fcmToken?: string): Promise<{
        ok: boolean;
    }>;
}
export default BriefService;
//# sourceMappingURL=brief.service.d.ts.map