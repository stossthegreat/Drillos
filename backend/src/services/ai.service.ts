// src/services/ai.service.ts
import OpenAI from "openai";
import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { MemoryService } from "./memory.service";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS || 400);
const LLM_TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS || 10000);

export type MentorId = "marcus" | "drill" | "confucius" | "lincoln" | "buddha";

const PERSONAS: Record<
  MentorId,
  { name: string; system: string; style: "strict" | "balanced" | "light" }
> = {
  marcus: {
    name: "Marcus Aurelius",
    style: "balanced",
    system: `You are Marcus Aurelius as a living Stoic mentor. Be terse, calm, stern but compassionate.
Use concrete orders. Praise discipline, scorn excuses. Favor present action over rumination.
Structure: (1) Truth, (2) Order to act, (3) Why it matters.`,
  },
  drill: {
    name: "Drill Sergeant",
    style: "strict",
    system: `You are a Drill Sergeant: direct, loud, no fluff, never abusive, always mission-first.
Structure: (1) Situation, (2) Command (short), (3) Immediate next step (very specific).`,
  },
  confucius: {
    name: "Confucius",
    style: "balanced",
    system: `You are Confucius: harmonious order, duty, virtue in daily acts.
Structure: (1) Principle, (2) Precise correction of imbalance, (3) Daily rite to restore order.`,
  },
  lincoln: {
    name: "Abraham Lincoln",
    style: "balanced",
    system: `You are Abraham Lincoln: measured, moral, practical. Govern the self as a republic.
Structure: (1) Moral frame, (2) Practical directive, (3) Long-term purpose.`,
  },
  buddha: {
    name: "Buddha",
    style: "light",
    system: `You are the Buddha: compassionate, piercing clarity, non-attachment, right effort.
Structure: (1) See clearly, (2) Release craving, (3) Single mindful action now.`,
  },
};

type GenerateOpts = {
  maxTokens?: number;
  temperature?: number;
  forceStyle?: "strict" | "balanced" | "light";
};

export class AIService {
  private memory: MemoryService;

  constructor() {
    this.memory = new MemoryService();
  }

  /**
   * Primary: generate a mentor reply that’s aware of:
   * - user profile (tone, intensity, timezone, mentor selection)
   * - current habits & completion today
   * - recent events (last 30–50)
   * - long-term memory (UserFacts.json)
   */
  async generateMentorReply(
    userId: string,
    mentorId: MentorId,
    userPrompt: string,
    opts: GenerateOpts = {}
  ): Promise<{ text: string; tokens?: number }> {
    // Load user
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error("User not found");

    // Persona & tone
    const persona = PERSONAS[mentorId] || PERSONAS.marcus;
    const style = opts.forceStyle || (user.tone as "strict" | "balanced" | "light") || persona.style;

    // Memory + recent signals
    const memory = await this.memory.get(userId);
    const habits = await prisma.habit.findMany({
      where: { userId },
      orderBy: { createdAt: "asc" },
    });
    const events = await prisma.event.findMany({
      where: { userId },
      orderBy: { ts: "desc" },
      take: 40,
    });

    // Brief snapshot for the model — concise, structured, real data
    const todayKey = new Date().toISOString().split("T")[0];
    const completedToday = habits
      .filter((h) => h.lastTick && new Date(h.lastTick).toISOString().startsWith(todayKey))
      .map((h) => ({ id: h.id, title: h.title, streak: h.streak }));
    const pending = habits
      .filter((h) => !h.lastTick || !new Date(h.lastTick).toISOString().startsWith(todayKey))
      .map((h) => ({ id: h.id, title: h.title, streak: h.streak }));

    const context = {
      profile: {
        tz: user.tz,
        tone: user.tone,
        intensity: user.intensity,
        plan: user.plan,
        mentorId,
      },
      memory: memory, // UserFacts.json full object
      habits: {
        total: habits.length,
        completedToday,
        pending,
        strongest: habits.length ? habits.slice().sort((a, b) => b.streak - a.streak)[0]?.title : null,
      },
      recentEvents: events.map((e) => ({
        id: e.id,
        ts: e.ts,
        type: e.type,
        payload: e.payload,
      })),
    };

    // Deduplicate fast repeat prompts for same user to save tokens (optional)
    const dedupeKey = `ai:last:${userId}:${mentorId}`;
    const lastHash = await redis.get(dedupeKey);
    const nowHash = hashSmall(userPrompt + JSON.stringify(context.habits.pending).slice(0, 512));
    if (lastHash && lastHash === nowHash) {
      // Return last response if we stored it
      const lastText = await redis.get(`${dedupeKey}:text`);
      if (lastText) return { text: lastText };
    }

    const systemPrompt = [
      `You are ${persona.name}.`,
      persona.system,
      `User tone=${style}, intensity=${user.intensity}. Be actionable, not vague.`,
      `Always give:`,
      `1) A short truth tailored to their pattern.`,
      `2) A single concrete next action (<= 20 words).`,
      `3) A brief why (<= 1 sentence).`,
      `Maximum 120–140 words.`,
    ].join("\n");

    const assistantContext = [
      `CONTEXT (do not repeat headings):`,
      `- Habits: total=${context.habits.total}, completed_today=${context.habits.completedToday.length}, pending=${context.habits.pending.length}`,
      context.habits.strongest ? `- Strongest habit: ${context.habits.strongest}` : `- Strongest habit: none`,
      `- Profile: tz=${context.profile.tz}, tone=${context.profile.tone}, intensity=${context.profile.intensity}, plan=${context.profile.plan}`,
      `- Memory highlights: ${summarizeMemory(memory)}`,
      `- Recent events (latest 5): ${context.recentEvents.slice(0, 5).map(e => `${e.type}`).join(", ") || "none"}`,
    ].join("\n");

    // Call OpenAI (Responses or Chat Completions).
    const temperature = typeof opts.temperature === "number" ? opts.temperature : (style === "strict" ? 0.4 : style === "balanced" ? 0.6 : 0.7);

    const response = await openai.chat.completions.create(
      {
        model: MODEL,
        temperature,
        max_tokens: Math.min(LLM_MAX_TOKENS, 400),
        messages: [
          { role: "system", content: systemPrompt },
          { role: "assistant", content: assistantContext },
          { role: "user", content: userPrompt || "Give guidance for right now." },
        ],
      },
      { timeout: LLM_TIMEOUT_MS }
    );

    const text = response.choices?.[0]?.message?.content?.trim() || "Act now: one clean rep. Then continue.";
    // Save output to events for audit & later learning
    await prisma.event.create({
      data: {
        userId,
        type: "ai_reply",
        payload: {
          mentorId,
          request: { userPrompt, style, intensity: user.intensity },
          contextSnapshot: {
            habits: {
              total: context.habits.total,
              completedToday: context.habits.completedToday.length,
              pending: context.habits.pending.length,
            },
          },
          reply: text,
          model: MODEL,
        },
      },
    });

    await redis.set(dedupeKey, nowHash, "EX", 60);
    await redis.set(`${dedupeKey}:text`, text, "EX", 60);

    return { text, tokens: response.usage?.total_tokens };
  }

  /**
   * Daily mission plan (short list) aware of schedule and pending.
   */
  async planDailyMissions(userId: string, mentorId: MentorId) {
    const habits = await prisma.habit.findMany({ where: { userId }, orderBy: { createdAt: "asc" } });
    const today = new Date().toISOString().split("T")[0];

    const pending = habits.filter((h) => !h.lastTick || !new Date(h.lastTick).toISOString().startsWith(today));
    // Sort by streak descending = protect streaks
    const prioritized = pending.slice().sort((a, b) => b.streak - a.streak).slice(0, 5);

    const items = prioritized.map((h) => ({
      habitId: h.id,
      title: h.title,
      reason: h.streak >= 5 ? "protect_streak" : "momentum",
    }));

    await prisma.event.create({
      data: {
        userId,
        type: "daily_plan",
        payload: { mentorId, items },
      },
    });

    return items;
  }
}

function hashSmall(s: string) {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return String(h >>> 0);
}

function summarizeMemory(mem: any): string {
  if (!mem || typeof mem !== "object") return "none";
  const keys = Object.keys(mem);
  if (!keys.length) return "none";
  // show a few stable keys
  const sample = keys.slice(0, 6).map((k) => `${k}:${short(JSON.stringify(mem[k]))}`);
  return sample.join("; ");
}
function short(s: string, n = 40) {
  if (!s) return "";
  return s.length > n ? s.slice(0, n) + "…" : s;
}

export const aiService = new AIService();
