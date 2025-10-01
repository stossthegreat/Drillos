// src/services/ai.service.ts
import { Configuration, OpenAIApi } from "openai";
import { MemoryService } from "./memory.service";
import { prisma } from "../utils/db";

export class AIService {
  private openai: OpenAIApi;
  private memory: MemoryService;

  constructor() {
    this.openai = new OpenAIApi(
      new Configuration({ apiKey: process.env.OPENAI_API_KEY })
    );
    this.memory = new MemoryService();
  }

  /**
   * Generates a mentor-style reply with full context.
   * @param userId - current user
   * @param mentor - "marcus" | "drill" | "confucius" | "lincoln" | "buddha"
   * @param message - user input or system message
   */
  async generateMentorReply(userId: string, mentor: string, message: string) {
    // get user facts + last 20 events for context
    const facts = await this.memory.getUserFacts(userId);
    const events = await prisma.event.findMany({
      where: { userId },
      orderBy: { ts: "desc" },
      take: 20,
    });

    const systemPrompt = `
You are ${mentor}, the user's chosen mentor. 
Speak in their style. Use the user's streaks, patterns, and context to motivate them.
Facts: ${JSON.stringify(facts)}
Recent events: ${JSON.stringify(events)}
Message from user: ${message}
Respond with actionable, emotionally impactful advice in <200 tokens.`;

    const completion = await this.openai.createChatCompletion({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      messages: [{ role: "system", content: systemPrompt }],
      max_tokens: Number(process.env.LLM_MAX_TOKENS || 300),
    });

    return completion.data.choices[0].message?.content || "";
  }
}
export const aiService = new AIService();
