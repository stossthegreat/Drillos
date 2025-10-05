import { type MentorId } from '../config/mentors.config';
type GenerateOptions = {
    purpose?: 'brief' | 'nudge' | 'debrief' | 'coach' | 'alarm';
    temperature?: number;
    maxChars?: number;
};
export declare class AIService {
    /**
     * Persona-aware, memory-aware mentor reply.
     * Bypasses paywall in DEV/TEST mode.
     */
    generateMentorReply(userId: string, mentorId: MentorId, userMessage: string, opts?: GenerateOptions): Promise<string>;
    generateMorningBrief(userId: string, mentorId: MentorId): Promise<string>;
    generateEveningDebrief(userId: string, mentorId: MentorId): Promise<string>;
    generateNudge(userId: string, mentorId: MentorId, reason: string): Promise<string>;
    private buildGuidelines;
    private defaultTempFor;
}
export declare const aiService: AIService;
export {};
