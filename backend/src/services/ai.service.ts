// src/services/ai.service.ts
import OpenAI from 'openai';
import { prisma } from '../utils/db';
import { memoryService } from './memory.service';
import { MENTORS, type MentorId } from '../config/mentors.config';
import { redis } from '../utils/redis';

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS || 450);
const LLM_TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS || 10000);

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  timeout: LLM_TIMEOUT_MS,
});

type GenerateOptions = {
  purpose?: 'brief' | 'nudge' | 'debrief' | 'coach' | 'alarm';
  temperature?: number;
  // optional: constrain length for push vs. chat
  maxChars?: number;
};

export class AIService {
  /**
   * Persona-aware, memory-aware mentor reply.
   * No mock: calls OpenAI with real context & saves event.
   */
  async generateMentorReply(userId: string, mentorId: MentorId, userMessage: string, opts: GenerateOptions = {}) {
    const mentor = MENTORS[mentorId];
    if (!mentor) throw new Error('Invalid mentor');

    // Pull compact profile + recent context
    const [profile, ctx] = await Promise.all([
      memoryService.getProfileForMentor(userId),
      memoryService.getUserContext(userId),
    ]);

    const guidelines = this.buildGuidelines(mentorId, opts.purpose || 'coach', profile);

    const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      { role: 'system', content: mentor.systemPrompt },
      { role: 'system', content: guidelines },
      {
        role: 'system',
        content:
          `CONTEXT:\n` +
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

    // Save AI interaction
    await prisma.event.create({
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

  /**
   * Task-specific generator helpers used by OS loop (morning brief / evening debrief / nudges)
   */
  async generateMorningBrief(userId: string, mentorId: MentorId) {
    const msg = await this.generateMentorReply(
      userId,
      mentorId,
      'Generate the morning brief: set the tone, list today’s 3 most important orders based on my habits and patterns. End with a single actionable order.',
      { purpose: 'brief', temperature: 0.4, maxChars: 500 }
    );
    return msg;
  }

  async generateEveningDebrief(userId: string, mentorId: MentorId) {
    // First, update memory with day summary
    await memoryService.summarizeDay(userId);

    const msg = await this.generateMentorReply(
      userId,
      mentorId,
      'Generate my evening debrief: reflect briefly on what I did well/poorly, connect to streaks, and set one precise order for tomorrow morning.',
      { purpose: 'debrief', temperature: 0.3, maxChars: 500 }
    );
    return msg;
  }

  async generateNudge(userId: string, mentorId: MentorId, reason: string) {
    const prompt = `Generate a short nudge due to: ${reason}. It must be sharp, 1-2 sentences max, ending with an imperative.`;
    return this.generateMentorReply(userId, mentorId, prompt, { purpose: 'nudge', temperature: 0.5, maxChars: 220 });
  }

  /**
   * Small helper: persona-specific guardrails for different purposes.
   */
  private buildGuidelines(mentorId: MentorId, purpose: NonNullable<GenerateOptions['purpose']>, profile: any) {
    const base = [
      `You are ${MENTORS[mentorId].displayName}. Write in that voice.`,
      `Match the user's plan/tone/intensity: plan=${profile.plan}, tone=${profile.tone}, intensity=${profile.intensity}`,
      `Never write profanity or abuse. Be firm, not cruel.`,
      `Be concise. Prefer action over theory.`,
    ];

    const byPurpose: Record<string, string[]> = {
      brief: [
        `Morning brief: energize, set 2-3 concrete orders based on habit data.`,
        `No fluff. One punchy closer line with an imperative.`,
      ],
      debrief: [
        `Evening debrief: 2-4 tight lines. Reflect truthfully. Praise/critique.`,
        `One concrete order for tomorrow.`,
      ],
      nudge: [
        `Nudge: 1-2 sentences only. Urgent, targeted, personalized.`,
      ],
      alarm: [
        `Alarm: short call to action aligned with time-of-day ritual.`,
      ],
      coach: [
        `Direct coaching: address weaknesses seen in context, give one clear next step.`,
      ],
    };

    return [...base, ...byPurpose[purpose]].join('\n');
  }

  private defaultTempFor(mentorId: MentorId) {
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

export const aiService = new AIService();
