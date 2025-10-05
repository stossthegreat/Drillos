// src/services/nudges.service.ts
import OpenAI from "openai";
import { prisma } from "../utils/db";
import { memoryService } from "./memory.service";
import { StreaksService } from "./streaks.service";
import { EventsService } from "./events.service";
import { VoiceService } from "./voice.service";
import { MENTORS, type MentorId } from "../config/mentors.config";

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
  
  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
}

export class NudgesService {
  private streaksService = new StreaksService();
  private eventsService = new EventsService();
  private voiceService = new VoiceService();

  /**
   * Generate nudges for a user, based on streaks, events, and memory.
   */
  async generateNudges(userId: string) {
    const openai = getOpenAIClient();
    if (!openai) {
      console.warn('⚠️ OpenAI not available, skipping nudge generation');
      return { success: false, nudges: [] };
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error("User not found");

    const mentorId: MentorId = (user as any).mentorId || "marcus";
    const mentor = MENTORS[mentorId];

    // Context building
    const streaks = await this.streaksService.getStreakSummary(userId);
    const patterns = await this.eventsService.getPatterns(userId);
    const memory = await memoryService.getUserContext(userId);
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
      let audioUrl: string | null = null;
      try {
        const voiceResult = await this.voiceService.speak(userId, text, mentorId);
        audioUrl = voiceResult.url;
      } catch {
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
      await prisma.event.create({
        data: { userId, type: "nudge_generated", payload: nudge },
      });
    }

    return { success: true, nudges, mentor: mentorId };
  }
}

export const nudgesService = new NudgesService();
