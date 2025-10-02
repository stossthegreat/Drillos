import { prisma } from "../utils/db";
import OpenAI from "openai";
import { VoiceService } from "./voice.service";
import { HabitsService } from "./habits.service";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const voiceService = new VoiceService();
const habitsService = new HabitsService();

export class BriefService {
  async getTodaysBrief(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    const habits = await habitsService.list(userId);

    const completed = habits.filter(h => h.status === "completed_today").length;
    const pending = habits.length - completed;

    const context = `
User: ${user?.id}
Mentor: ${user?.mentorId ?? "marcus"}
Habits: ${habits.map(h => `${h.title} (streak ${h.streak}, status ${h.status})`).join(", ")}
Stats: ${completed} completed, ${pending} pending
`;

    const prompt = `
You are ${user?.mentorId ?? "Marcus Aurelius"}.
Write a short, powerful morning briefing to this user.
Tone = strict / stoic / balanced depending on mentor.
Focus on today's pending habits and streak risks.
`;

    const ai = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      max_tokens: 200,
      messages: [
        { role: "system", content: context },
        { role: "user", content: prompt },
      ],
    });

    const text = ai.choices[0].message?.content ?? "Begin your mission today.";
    const voiceResult = await voiceService.speak(userId, text, user?.mentorId ?? "marcus");
    const voiceUrl = voiceResult.url;

    return {
      mentor: user?.mentorId,
      message: text,
      audio: voiceUrl,
      missions: habits,
    };
  }

  async getEveningDebrief(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    const habits = await habitsService.list(userId);

    const completed = habits.filter(h => h.status === "completed_today").length;

    const prompt = `
You are ${user?.mentorId ?? "Drill Sergeant"}.
Write an evening debrief about the user's performance.
Mention completed ${completed}/${habits.length}.
Be encouraging but hold them accountable.
`;

    const ai = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      max_tokens: 200,
      messages: [{ role: "user", content: prompt }],
    });

    const text = ai.choices[0].message?.content ?? "Reflect and prepare for tomorrow.";
    const voiceResult = await voiceService.speak(userId, text, user?.mentorId ?? "drill");
    const voiceUrl = voiceResult.url;

    return {
      mentor: user?.mentorId,
      message: text,
      audio: voiceUrl,
      stats: { completed, total: habits.length },
    };
  }
}

export const briefService = new BriefService();
