"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiService = exports.AIService = void 0;
// src/services/ai.service.ts
const openai_1 = __importDefault(require("openai"));
const db_1 = require("../utils/db");
const memory_service_1 = require("./memory.service");
const mentors_config_1 = require("../config/mentors.config");
const redis_1 = require("../utils/redis");
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS || 450);
const LLM_TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS || 10000);
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
    return new openai_1.default({
        apiKey: process.env.OPENAI_API_KEY,
        timeout: LLM_TIMEOUT_MS,
    });
}
class AIService {
    /**
     * Persona-aware, memory-aware mentor reply.
     * Bypasses paywall in DEV/TEST mode.
     */
    async generateMentorReply(userId, mentorId, userMessage, opts = {}) {
        const openai = getOpenAIClient();
        if (!openai) {
            console.warn('⚠️ OpenAI not available, using fallback response');
            return 'I am temporarily unavailable. Please try again later.';
        }
        const mentor = mentors_config_1.MENTORS[mentorId];
        if (!mentor)
            throw new Error('Invalid mentor');
        // 🟢 BYPASS paywall/quota for dev/test
        if (process.env.NODE_ENV !== 'production' || process.env.ALLOW_FREE_AI === 'true') {
            console.log('⚠️ Bypass AI paywall: free AI access in dev/test mode');
        }
        else {
            // In prod, check quota (only PRO users can use AI)
            const user = await db_1.prisma.user.findUnique({ where: { id: userId } });
            if (user?.plan !== 'PRO') {
                throw new Error('AI access requires PRO subscription');
            }
            const today = new Date().toISOString().split('T')[0];
            const quotaKey = `quota:ai:${userId}:${today}`;
            const used = parseInt((await redis_1.redis.get(quotaKey)) || '0', 10);
            const cap = Number(process.env.LLM_DAILY_MSG_CAP_PRO || 150);
            if (used >= cap)
                throw new Error('AI daily quota exceeded');
            await redis_1.redis.incr(quotaKey);
            await redis_1.redis.expire(quotaKey, 60 * 60 * 24);
        }
        // Pull context for memory + habits
        const [profile, ctx] = await Promise.all([
            memory_service_1.memoryService.getProfileForMentor(userId),
            memory_service_1.memoryService.getUserContext(userId),
        ]);
        const guidelines = this.buildGuidelines(mentorId, opts.purpose || 'coach', profile);
        const messages = [
            { role: 'system', content: mentor.systemPrompt },
            { role: 'system', content: guidelines },
            {
                role: 'system',
                content: `CONTEXT:\n` +
                    `Profile: ${JSON.stringify(profile)}\n` +
                    `Habits: ${JSON.stringify(ctx.habitSummaries)}\n` +
                    `RecentEvents: ${JSON.stringify(ctx.recentEvents.slice(0, 40))}`,
            },
            { role: 'user', content: userMessage },
        ];
        const completion = await openai.chat.completions.create({
            model: OPENAI_MODEL,
            temperature: opts.temperature ?? this.defaultTempFor(mentorId),
            max_tokens: LLM_MAX_TOKENS,
            messages,
        });
        let text = completion.choices[0]?.message?.content?.trim() || '';
        if (opts.maxChars && text.length > opts.maxChars) {
            text = text.slice(0, opts.maxChars - 1) + '…';
        }
        // Save AI interaction as event
        await db_1.prisma.event.create({
            data: {
                userId,
                type: 'mentor_reply',
                payload: {
                    mentorId,
                    purpose: opts.purpose || 'coach',
                    text,
                },
            },
        });
        return text;
    }
    async generateMorningBrief(userId, mentorId) {
        return this.generateMentorReply(userId, mentorId, 'Generate my morning brief: set the tone, list my top 3 orders for today, end with one imperative.', { purpose: 'brief', temperature: 0.4, maxChars: 500 });
    }
    async generateEveningDebrief(userId, mentorId) {
        await memory_service_1.memoryService.summarizeDay(userId);
        return this.generateMentorReply(userId, mentorId, 'Generate my evening debrief: reflect on successes/failures, streaks, and end with 1 order for tomorrow.', { purpose: 'debrief', temperature: 0.3, maxChars: 500 });
    }
    async generateNudge(userId, mentorId, reason) {
        const prompt = `Generate a sharp nudge because: ${reason}. Keep it 1–2 sentences, end with a direct order.`;
        return this.generateMentorReply(userId, mentorId, prompt, { purpose: 'nudge', temperature: 0.5, maxChars: 220 });
    }
    buildGuidelines(mentorId, purpose, profile) {
        const base = [
            `You are ${mentors_config_1.MENTORS[mentorId].displayName}. Write in their exact voice.`,
            `Match user profile: plan=${profile.plan}, tone=${profile.tone}, intensity=${profile.intensity}`,
            `No profanity. Firm but not cruel.`,
            `Be concise. Action > theory.`,
        ];
        const byPurpose = {
            brief: [`Morning brief: 2–3 orders, 1 punchy closing line.`],
            debrief: [`Evening debrief: 2–4 lines, mix praise/critique, 1 order for tomorrow.`],
            nudge: [`Nudge: urgent, 1–2 sentences max, actionable.`],
            alarm: [`Alarm: short ritual command for time-of-day.`],
            coach: [`Direct coaching: call out weakness, give 1 clear next step.`],
        };
        return [...base, ...byPurpose[purpose]].join('\n');
    }
    defaultTempFor(mentorId) {
        switch (mentorId) {
            case 'drill': return 0.4;
            case 'marcus': return 0.3;
            case 'confucius': return 0.35;
            case 'lincoln': return 0.35;
            case 'buddha': return 0.3;
            default: return 0.4;
        }
    }
}
exports.AIService = AIService;
exports.aiService = new AIService();
