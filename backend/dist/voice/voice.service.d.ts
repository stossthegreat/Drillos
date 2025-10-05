type GetAudioInput = {
    userId: string;
    mentor?: 'marcus' | 'confucius' | 'lincoln' | 'buddha' | 'sergeant' | string;
    tone?: 'strict' | 'balanced' | 'light' | string;
    presetId?: string;
    text?: string;
};
export declare class VoiceService {
    private readonly elevenKey;
    private readonly s3;
    private readonly bucket;
    private readonly ttsTimeout;
    private pickVoiceId;
    private cacheKeyFromText;
    private urlForS3Key;
    private uploadToS3;
    private synthesizeWithElevenLabs;
    private mentorLine;
    getAudioUrl(input: GetAudioInput): Promise<{
        url: string | null;
    }>;
}
export default VoiceService;
//# sourceMappingURL=voice.service.d.ts.map