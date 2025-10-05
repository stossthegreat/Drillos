export declare class NudgesService {
    private streaksService;
    private eventsService;
    private voiceService;
    /**
     * Generate nudges for a user, based on streaks, events, and memory.
     */
    generateNudges(userId: string): Promise<any[]>;
}
export declare const nudgesService: NudgesService;
