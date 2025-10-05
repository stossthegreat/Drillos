export declare class VoiceService {
    /**
     * Main: get TTS audio URL for a mentor/voice + text, with real caching.
     */
    speak(userId: string, text: string, voiceKey: string): Promise<{
        url: string;
        cached: boolean;
    }>;
    /**
     * Alias for speak() that returns just the URL string (backward compatibility)
     */
    ttsToUrl(userId: string, text: string, voiceKey: string): Promise<string>;
    private hash;
}
export declare const voiceService: VoiceService;
