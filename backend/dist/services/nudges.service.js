"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.nudgesService = exports.NudgesService = void 0;
// src/services/nudges.service.ts
const openai_1 = __importDefault(require("openai"));
const db_1 = require("../utils/db");
const memory_service_1 = require("./memory.service");
const streaks_service_1 = require("./streaks.service");
const events_service_1 = require("./events.service");
const voice_service_1 = require("./voice.service");
const mentors_config_1 = require("../config/mentors.config");
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
// Lazy OpenAI initialization - only when actually needed
function getOpenAIClient() {
    // Skip OpenAI initialization during build process
    if (process.env.NODE_ENV === 'build' || process.env.RAILWAY_ENVIRONMENT === 'build') {
        return null;
    }
    // Validate required environment variables
    if (!process.env.OPENAI_API_KEY) {
        console.warn('⚠️ OpenAI API key not available, AI features will be disabled');
        return null;
    }
    return new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
}
class NudgesService {
    streaksService = new streaks_service_1.StreaksService();
    eventsService = new events_service_1.EventsService();
    voiceService = new voice_service_1.VoiceService();
    /**
     * Generate nudges for a user, based on streaks, events, and memory.
     */
    async generateNudges(userId) {
        const openai = getOpenAIClient();
        if (!openai) {
            console.warn('⚠️ OpenAI not available, skipping nudge generation');
            return { success: false, nudges: [] };
        }
        const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
        if (!user)
            throw new Error("User not found");
        const mentorId = user.mentorId || "marcus";
        const mentor = mentors_config_1.MENTORS[mentorId];
        // Context building
        const streaks = await this.streaksService.getStreakSummary(userId);
        const patterns = await this.eventsService.getPatterns(userId);
        const memory = await memory_service_1.memoryService.getUserContext(userId);
        const eventSummary = await this.eventsService.summarizeForAI(userId);
        const context = `
User: ${userId}
Mentor: ${mentor.displayName}
Current streak summary: ${JSON.stringify(streaks)}
Recent patterns: ${JSON.stringify(patterns)}
Memory facts: ${JSON.stringify(memory.facts)}
Habit summaries: ${JSON.stringify(memory.habitSummaries)}
Event log:\n${eventSummary}
`;
        const prompt = `
You are ${mentor.displayName}. Voice: ${mentor.style}.
Write exactly 2 nudges (1–2 sentences each).
- Nudge 1: Push discipline, action, momentum.
- Nudge 2: Warn against repeating recent mistakes, based on patterns/memory.
Return plain text, separated by "---".
Tone: ${mentor.style}, no fluff, straight orders.
`;
        const ai = await openai.chat.completions.create({
            model: OPENAI_MODEL,
            max_tokens: 250,
            temperature: 0.5,
            messages: [
                { role: "system", content: context },
                { role: "user", content: prompt },
            ],
        });
        const raw = ai.choices[0].message?.content ?? "";
        const parts = raw.split("---").map(p => p.trim()).filter(Boolean);
        const nudges = [];
        for (const text of parts) {
            let audioUrl = null;
            try {
                const voiceResult = await this.voiceService.speak(userId, text, mentorId);
                audioUrl = voiceResult.url;
            }
            catch {
                audioUrl = null;
            }
            const nudge = {
                type: "mentor_nudge",
                mentor: mentorId,
                message: text,
                audio: audioUrl,
                priority: "high",
            };
            nudges.push(nudge);
            // Log in DB
            await db_1.prisma.event.create({
                data: { userId, type: "nudge_generated", payload: nudge },
            });
        }
        return { success: true, nudges, mentor: mentorId };
    }
}
exports.NudgesService = NudgesService;
exports.nudgesService = new NudgesService();
