import OpenAI from "openai";
import { StreaksService } from "./streaks.service";
import { EventsService } from "./events.service";
import { VoiceService } from "./voice.service";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export class NudgesService {
  private streaksService = new StreaksService();
  private eventsService = new EventsService();
  private voiceService = new VoiceService();

  async generateNudges(userId: string) {
    const streaks = await this.streaksService.getStreakSummary(userId);
    const patterns = await this.eventsService.getPatterns(userId);
    const eventSummary = await this.eventsService.summarizeForAI(userId);

    const context = `
User: ${userId}
Current streak summary: ${JSON.stringify(streaks)}
Recent patterns: ${JSON.stringify(patterns)}
Event log:\n${eventSummary}
`;

    const prompt = `
You are this user's chosen mentor (Marcus Aurelius, Drill Sergeant, Confucius, Lincoln, Buddha).
Write 2 short nudges (1–2 sentences each).
- Be personal (based on streaks & patterns).
- One nudge should push discipline.
- One should warn against repeating recent mistakes.
Return them as plain text, separated by "---".
`;

    const ai = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      max_tokens: 250,
      messages: [
        { role: "system", content: context },
        { role: "user", content: prompt },
      ],
    });

    const raw = ai.choices[0].message?.content ?? "";
    const parts = raw.split("---").map(p => p.trim()).filter(Boolean);

    // Generate voice for each nudge
    const nudges = [];
    for (const text of parts) {
      const audioUrl = await this.voiceService.speak("marcus", text); // TODO: use user.mentorId
      nudges.push({
        type: "mentor_nudge",
        message: text,
        audio: audioUrl,
        priority: "high",
      });
    }

    return nudges;
  }
}
