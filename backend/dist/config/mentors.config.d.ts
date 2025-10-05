export type MentorId = 'marcus' | 'drill' | 'confucius' | 'lincoln' | 'buddha';
export type MentorConfig = {
    id: MentorId;
    displayName: string;
    style: 'strict' | 'balanced' | 'light' | 'inspirational' | 'stoic';
    voiceIdEnv: string;
    systemPrompt: string;
};
export declare const MENTORS: Record<MentorId, MentorConfig>;
export declare function getMentorVoiceId(mentorId: MentorId): string | undefined;
