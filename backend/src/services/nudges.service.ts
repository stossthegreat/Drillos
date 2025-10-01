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

    const context = `
User ID: ${userId}
Current streaks: ${JSON.stringify(streaks)}
Behavior patterns: ${JSON.stringify(patterns)}
`;

    const prompt = `
Act as the user's mentor.
Write 2 short nudges to push them back on track.
Tone: strict, stoic, or balanced (depending on mentor).
Make it personal to their patterns and streaks.
`;

    const ai = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      max_tokens: 200,
      messages: [
        { role: "system", content: context },
        { role: "user", content: prompt },
      ],
    });

    const text = ai.choices[0].message?.content ?? "Keep going.";
    const voiceUrl = await this.voiceService.speak("marcus", text);

    return [
      {
        type: "mentor_nudge",
        message: text,
        audio: voiceUrl,
        priority: "high",
      },
    ];
  }
}
