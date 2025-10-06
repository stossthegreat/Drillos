import { prisma } from "../utils/db";
import OpenAI from "openai";
import { VoiceService } from "./voice.service";
import { habitsService } from "./habits.service";
import { tasksService } from "./tasks.service";

// Lazy OpenAI initialization - only when actually needed
function getOpenAIClient() {
  if (process.env.NODE_ENV === 'build' || process.env.RAILWAY_ENVIRONMENT === 'build') {
    return null;
  }

  if (!process.env.OPENAI_API_KEY) {
    console.warn('⚠️ OpenAI API key not available, AI features will be disabled');
    return null;
  }

  return new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
}

const voiceService = new VoiceService();
// habitsService is already imported as an object

export class BriefService {
  async getTodaysBrief(userId: string) {
    const openai = getOpenAIClient();
    if (!openai) {
      console.warn('⚠️ OpenAI not available, using fallback brief');

      const user = await prisma.user.findUnique({ where: { id: userId } });
      const habits = await habitsService.list(userId);
      const tasks = await tasksService.list(userId, false);

      const todaySelections = await prisma.todaySelection.findMany({
        where: { userId, date: new Date().toISOString().split('T')[0] },
        include: { habit: true, task: true },
      });

      const today = todaySelections.map(selection => {
        if (selection.habit) {
          return {
            id: selection.habit.id,
            name: selection.habit.title,
            type: 'habit',
            completed: selection.habit.lastTick
              ? new Date(selection.habit.lastTick).toDateString() === new Date().toDateString()
              : false,
            streak: selection.habit.streak,
            color: (selection.habit as any).color ?? 'emerald',
            reminderEnabled: (selection.habit as any).reminderEnabled ?? false,
            reminderTime: (selection.habit as any).reminderTime ?? null,
          };
        } else if (selection.task) {
          return {
            id: selection.task.id,
            name: selection.task.title,
            type: 'task',
            completed: selection.task.completed,
            priority: selection.task.priority,
          };
        }
        return null;
      }).filter(Boolean);

      return {
        mentor: user?.mentorId ?? 'marcus',
        message: 'Begin your mission today.',
        audio: null,
        missions: habits,
        habits,
        tasks,
        today,
      };
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    const habits = await habitsService.list(userId);
    const tasks = await tasksService.list(userId, true); // Include completed tasks

    const completed = habits.filter(h => h.completedToday).length;
    const pending = habits.length - completed;

    const context = `
User: ${user?.id}
Mentor: ${user?.mentorId ?? "marcus"}
Habits: ${habits.map(h => `${h.title} (streak ${h.streak}, completedToday ${h.completedToday})`).join(", ")}
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

    const todaySelections = await prisma.todaySelection.findMany({
      where: { userId, date: new Date().toISOString().split('T')[0] },
      include: { habit: true, task: true },
    });

    const today = todaySelections.map(selection => {
      if (selection.habit) {
        return {
          id: selection.habit.id,
          name: selection.habit.title,
          type: 'habit',
          completed: selection.habit.lastTick
            ? new Date(selection.habit.lastTick).toDateString() === new Date().toDateString()
            : false,
          streak: selection.habit.streak,
          color: (selection.habit as any).color ?? 'emerald',
          reminderEnabled: (selection.habit as any).reminderEnabled ?? false,
          reminderTime: (selection.habit as any).reminderTime ?? null,
        };
      } else if (selection.task) {
        return {
          id: selection.task.id,
          name: selection.task.title,
          type: 'task',
          completed: selection.task.completed,
          priority: selection.task.priority,
        };
      }
      return null;
    }).filter(Boolean);

    return {
      mentor: user?.mentorId,
      message: text,
      audio: voiceUrl,
      missions: habits,
      habits,
      tasks,
      today,
    };
  }

  async getEveningDebrief(userId: string) {
    const openai = getOpenAIClient();
    if (!openai) {
      console.warn('⚠️ OpenAI not available, using fallback debrief');
      return {
        mentor: "drill",
        message: "Reflect and prepare for tomorrow.",
        audio: null,
        stats: { completed: 0, total: 0 },
      };
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    const habits = await habitsService.list(userId);

    const completed = habits.filter(h => h.completedToday).length;

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
