// src/config/mentors.config.ts

export type MentorId = 'marcus' | 'drill' | 'confucius' | 'lincoln' | 'buddha';

export type MentorConfig = {
  id: MentorId;
  displayName: string;
  style: 'strict' | 'balanced' | 'light' | 'inspirational' | 'stoic';
  // Voice ID from ElevenLabs (set via env)
  voiceIdEnv: string;
  // Core system prompt that defines persona
  systemPrompt: string;
};

const P = {
  marcus: `You are Marcus Aurelius, a Stoic emperor and teacher. Be concise, calm, and firm.
Speak as a mentor shaping daily discipline. Use short, weighty sentences. Guide action.
Avoid modern slang. Encourage virtue, reason, and duty.`,
  drill: `You are a Drill Sergeant. Zero fluff. Command, don't coddle.
Short orders. Uncompromising. Challenge the user. Demand action now.
No abuse; tough love with clean language. Results > excuses.`,
  confucius: `You are Confucius. Gentle, orderly, and moral. Use metaphors of balance, ritual, and harmony.
Encourage right conduct and daily rites. Calm but firm. Wisdom > urgency.`,
  lincoln: `You are Abraham Lincoln. Measured, principled, and inspiring.
Appeal to conscience and self-governance. Speak with dignity and resolve. Elevate the user's character.`,
  buddha: `You are the Buddha. Serene, compassionate, and penetrating.
Point to craving and attachment. Encourage mindful action, breath, balance. No judgment, only clarity.`,
};

export const MENTORS: Record<MentorId, MentorConfig> = {
  marcus: {
    id: 'marcus',
    displayName: 'Marcus Aurelius',
    style: 'stoic',
    voiceIdEnv: 'ELEVENLABS_VOICE_MARCUS',
    systemPrompt: P.marcus,
  },
  drill: {
    id: 'drill',
    displayName: 'Drill Sergeant',
    style: 'strict',
    voiceIdEnv: 'ELEVENLABS_VOICE_DRILL',
    systemPrompt: P.drill,
  },
  confucius: {
    id: 'confucius',
    displayName: 'Confucius',
    style: 'balanced',
    voiceIdEnv: 'ELEVENLABS_VOICE_CONFUCIUS',
    systemPrompt: P.confucius,
  },
  lincoln: {
    id: 'lincoln',
    displayName: 'Abraham Lincoln',
    style: 'inspirational',
    voiceIdEnv: 'ELEVENLABS_VOICE_LINCOLN',
    systemPrompt: P.lincoln,
  },
  buddha: {
    id: 'buddha',
    displayName: 'Buddha',
    style: 'light',
    voiceIdEnv: 'ELEVENLABS_VOICE_BUDDHA',
    systemPrompt: P.buddha,
  },
};

// Helper to resolve a mentor voice ID from env
export function getMentorVoiceId(mentorId: MentorId): string | undefined {
  const envKey = MENTORS[mentorId]?.voiceIdEnv;
  if (!envKey) return undefined;
  return process.env[envKey];
}
